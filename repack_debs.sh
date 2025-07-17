#!/bin/bash -e
# vim:sw=4:ts=4:et

readonly DEBS_DIR=`pwd`/.debs;
readonly SOURCE_SCRIPT=$(cat <<EOF

PATH="/usr/local/erlang/\$vsn/bin:\$PATH"
PATH="/usr/local/erlang/\$vsn/erts-8.3.5.7/bin:\$PATH"
PATH="/usr/local/erlang/\$vsn/lib/erl_interface-3.9.3/bin:\$PATH"
PATH="/usr/local/erlang/\$vsn/lib/observer-2.3.1/priv/bin:\$PATH"
PATH="/usr/local/erlang/\$vsn/lib/os_mon-2.4.2/priv/bin:\$PATH"

export PATH;
echo "Activate erlang \$vsn";
EOF
)

function get_debs() {
    bash -c "cd $DEBS_DIR; ls *.deb";
}

function repack_deb:control() {
    local otp_vsn="$1";
    mkdir .tmp/.control;
    local extract_flag="";
    local control_file=$(cd .tmp; ls control.tar*)
    case ${control_file#*.} in
        tar.gz)
            extract_flag="-z";
            ;;
        tar.xz)
            extract_flag=;
            ;;
        tar.bzip2)
            extract_flag="-j";
            ;;
        *)
            echo "Unknown file ending '${control_file#*.}'" >&2;
            rm -rf .tmp;
            exit 1;
            ;;
    esac;
    echo "Extracting control files..." >&2
    tar -C .tmp/.control $extract_flag -xf .tmp/$control_file;

    function rework_depends() {
        echo "Reworking control file depends..." >&2
        local control_file=$1;

        local depends_line=$(sed -n 's/Depends:\(.*\)/\1/p' $control_file);

        local depends="";
        local recommends="";

        local deps;
        IFS=',' read -ra deps <<< "$depends_line"
        local dep;
        for dep in "${deps[@]}"; do
            local target;
            dep=`echo $dep`;
            if [[ -z "$dep" ]]; then
                continue;
            fi;
            if [[ "$dep" =~ "libssl" ]] || [[ "$dep" =~ "libwx" ]] || [[ "$dep" =~ "libsctp" ]]; then
                target=recommends;
            else
                target=depends;
            fi;
            if [[ -z "${!target}" ]]; then
                eval "${target}='$dep'"
            else
                eval "${target}='${!target}, $dep'"
            fi;
        done;
        local existing_recommends=$(sed -n 's/Recommends:\(.*\)/\1/p' $control_file)

        if [[ -n "$existing_recommends" ]]; then
            if [[ -z "$recommends" ]]; then
                recommends=$existing_recommends;
            else
                recommends="${recommends}, $existing_recommends";
            fi;
        fi;

        sed "s/\\(Package:.*\\)/\1-${otp_vsn}/g;s/Depends:.*/Depends: $depends/g;s/Recommends:.*/Recommends: $recommends/g;s/Conflicts:.*/Conflicts: /g" -i $control_file
    }

    rework_depends .tmp/.control/control;   
    echo "/usr/local/erlang/$otp_vsn/Install -minimal /usr/local/erlang/$otp_vsn/" > .tmp/.control/postinst
 
    rm -f .tmp/$control_file;
    echo "Re-Archiving control files..." >&2;
    tar --owner=root --group=root -C .tmp/.control/ -czf .tmp/control.tar.gz .
    rm -rf .tmp/.control;
}

function repack_deb:data() {
    mkdir .tmp/.data;
    local extract_flag="";
    local data_file=$(cd .tmp; ls data.tar*)
    case ${data_file#*.} in
        tar.gz)
            extract_flag="-z";
            ;;
        tar.xz)
            extract_flag=;
            ;;
        tar.bzip2)
            extract_flag="-j";
            ;;
        *)
            echo "Unknown file ending '${data_file#*.}'" >&2;
            rm -rf .tmp;
            exit 1;
            ;;
    esac;
    echo "Extracting data files..." >&2
    tar -C .tmp/.data $extract_flag -xf .tmp/$data_file;
    local otp_vsn=$(find .tmp/.data/usr -name 'OTP_VERSION' | xargs cut -d'.' -f1);
    mkdir -p .tmp/.data/usr/local/erlang;
    mv .tmp/.data/usr/lib/erlang .tmp/.data/usr/local/erlang/$otp_vsn;
    { echo "vsn=$otp_vsn;"; echo "${SOURCE_SCRIPT}"; } > .tmp/.data/usr/local/erlang/$otp_vsn/activate
    mv .tmp/.data/usr/share/doc/esl-erlang .tmp/.data/usr/share/doc/esl-erlang-${otp_vsn}
    rm -rf .tmp/.data/usr/bin
    rm -rf .tmp/.data/usr/lib
    
    rm -f .tmp/$data_file;
    echo "Re-Archiving data files..." >&2;
    tar --owner=root --group=root -C .tmp/.data/ -czf .tmp/data.tar.gz .
    rm -rf .tmp/.data;
    echo $otp_vsn;
}

function repack_deb() {
    local deb="$1";
    if [[ -d .tmp ]]; then
        rm -rf .tmp;
    fi;
    mkdir -p .tmp;
    echo "Unpacking ${deb}..."
    ar x ${DEBS_DIR}/$deb --output .tmp/
    local otp_vsn=$(repack_deb:data);
    repack_deb:control "$otp_vsn";
    echo "Repacking ${deb}...";
    ar rcs REPACKED-${deb} .tmp/debian-binary .tmp/* > /dev/null
    echo "Finished repacking! REPACKED-${deb}"
    rm -rf .tmp;
}

function main() {
    local debs=( $(get_debs) );
    for deb in "${debs[@]}"; do
        repack_deb "$deb"
    done;
}

main "$@"
