#!/bin/bash +x
if [[ 0 -eq $(id |grep -o -P '^uid=\d+' |cut -f2 -d=) ]]
then
    read -p'NOTE: Please run as sudo-prived user <CONTROL-C>' -t10
    exit 5
fi
# Establish base of version-controlled code tree.
[[ -z $SOURCEBASE ]] && declare -x SOURCEBASE=${HOME}'/freeitathenscode'
[[ -d $SOURCEBASE ]] || exit 25
# Establish location of these scripts within SOURCEBASE
codebase=${SOURCEBASE}'/image_scripts'
[[ -d $codebase ]] || exit 14
declare -x codebase
source ${codebase}/Prepare_functions || exit 136

Mainline() {

    declare -g MAX_RC=0
    select Funk in\
        EXIT\
	FINISH\
	Establish_sudo\
	housekeeping\
	integrity_test\
	swap_check\
	package_mgmt\
        BPR_custom\
	not_rms_happiness
    do
	case $Funk in
	    EXIT)
		return 0
		;;
	    FINISH)
		break
		;;
	    Establish_sudo)
		sudo ifconfig || return $?
		;;
	    housekeeping)
		Housekeeping
		;;
	    integrity_test)
		Integrity_check
		;;
	    swap_check)
		Swap_check
		;;
	    package_mgmt)
		Install_Remove_requested_packages
		;;
	    BPR_custom)
		Apply_custom_config
		;;
	    check_wallpaper)
		Check_Setup_wallpaper;RCxW=$?
		Report_Check_Setup_wallpaper $RCxW
                ;;
	    not_rms_happiness)
		Launch_virtual_greybeard
		;;
	    *)
		echo 'System error, unknown function '$Funk
		exit 12
		;;
	esac
    done

    [[ $live_run == 'Y' ]] &&\
        Cleanup_nouser_nogroup ${HOME}'/Ran_nouser_nogroup_fix'

    return 0
}

Housekeeping() {

    sys_rpts_distro_name=''
    if [ -z $DISTRO_NAME ]
    then
        Distro_name_Set;RCxDnS=$?
        if [ $RCxDnS -gt 0 ]
        then
            echo 'Distro_name_set ='$RCxDnS
            read -p'<ENTER>'
            No_distro_name_bye $RCxDnS
        else
            Pauze 'Good Selection!:'$DISTRO_NAME
        fi
    fi

    address_len=0
    Get_Address_Len
    Confirm_DISTRO_CPU || User_no_distro_bye $?

    [[ "${refresh_updatedb}." == 'Y.' ]] && sudo updatedb
    [[ "${refresh_svn}." == 'Y.' ]] && Contact_server

    Run_apt_update

    return 0
}

Distro_name_Set() {

    Pauze 'No distro supplied in parms. (e.g., -d FRITAROX)...'
    Set_sys_rpts_distro_name;RCxS=$?
    [[ $RCxS -eq 0 ]] || return 30

    DISTRO_NAME=$sys_rpts_distro_name
    #echo 'set' \$DISTRO_NAME '= '$DISTRO_NAME
    Answer='N'
    Pause_n_Answer 'Y|N' '...system value '${DISTRO_NAME}' is used, OK? '
    [[ "${Answer}." == 'Y.' ]] || return 12

    return 0
}

Set_Confirm_distro_name() {
    DISTRO_NAME=$1
    [[ -z $DISTRO_NAME ]] && return 40

    echo -e "\n\e[1;32;40mEvaluating your input: ${DISTRO_NAME}\n"
    read -p'<ENTER>' -t3

    Set_sys_rpts_distro_name;RCxS=$?
    if [ $RCxS -gt 0 ]
    then
        echo 'Cant confirm your distro name '\
            $DISTRO_NAME' against the system name(s)'
        read -p'<ENTER>' -t3
        return 2
    fi

    if [ "${DISTRO_NAME}." == "${sys_rpts_distro_name}." ]
    then
        echo 'System distro value ('${sys_rpts_distro_name}\
        ') agrees with your input ('${DISTRO_NAME}').'
        read -p'<ENTER>' -t3
        return 0
    fi

    echo 'System distro value ('\
        ${sys_rpts_distro_name}\
          '): mismatch (however slight) with your supplied name: ('\
        ${DISTRO_NAME}').'
    echo ''
    read -p'<ACCEPT System Value?>' -a ANS_ARR;echo ''
    [[ ${#ANS_ARR[*]} -gt 0 ]] &&\
        [[ ${ANS_ARR[0]} == 'Y' ]] &&\
        DISTRO_NAME=$sys_rpts_distro_name &&\
        return 0

    return 3
}

Set_sys_rpts_distro_name() {

    sys_rpts_distro_name=$(lsb_release -a 2>/dev/null\
            |grep '^Distributor ID:'|cut -f2 -d:\
            |sed -e 's/^[ \t]*//')

    if [ -n ${sys_rpts_distro_name} ]
    then
        echo 'System reports distro as '${sys_rpts_distro_name}'.' >&2
        return 0
    fi

    # Try other methods
    if [ "${SESSION}." == 'Lubuntu.' ]
    then
        sys_rpts_distro_name=$SESSION
        echo 'Using session name '$sys_rpts_distro_name' as distribution.'
        read -p'<ENTER>' -t3
        return 0
    fi

    # Tell calling routing we can't system-set distro name.
    return 12
}

No_distro_name_bye() {
    local RCxDC=${1:-98}

    prettyprint '1,31,40,M,n' 'Cannot Set Distro name'
    Pauze 'Exiting....'

    exit $RCxDC
}

Confirm_DISTRO_CPU() {

    distro_valid_flag='?'
    prettyprint '1,32,40,M,0' $DISTRO_NAME' is'
    case $DISTRO_NAME in
    LinuxMint|mint)
        distro_generia='mint'
        distro_valid_flag='Y'
        prettyprint '1,34,40,M' ' a valid'
        ;;
    debian|Solyd*)
        distro_generia='debian'
        distro_valid_flag='Y'
        prettyprint '1,34,40,M' ' a valid'
        ;;
    lubuntu|Ubuntu)
        distro_generia='ubuntu'
        distro_valid_flag='Y'
        prettyprint '1,34,40,M' ' a valid'
        ;;
    redhat|slackware|SuSE|crunchbang)
        distro_generia='other'
        distro_valid_flag='Y'
        prettyprint '1,34,40,M' " a valid (but you're on your own...)"
        ;;
    *)
        distro_generia='LINUX_DISTRO_not_appearing_in_this_film_WARE'
        distro_valid_flag='N'
        prettyprint '1,31,40,M' ' an INVALID'
        ;;
    esac
    prettyprint '1,32,40,M,n' ' distribution name.'
    [[ $distro_valid_flag != 'Y' ]] && return 16

    prettyprint '0,1,32,40,M,n'\
'Using general distro (category) name of '$distro_generia'.'
    Pauze "INFO,Confirmed $DISTRO_NAME on ${address_len}-bit box."

    return 0

}

User_no_distro_bye() {
    local RCxDC=${1:-99}

    prettyprint '5,31,47,M,n,0' 'No Known Distro Name, Exiting.'
    Pauze "See you back soon!"

    exit $RCxDC
}

Integrity_check() {

    local_scripts_DIR="${HOME}/bin"
    [[ -d $local_scripts_DIR ]] || mkdir $local_scripts_DIR
    sudo chown -c -R $realuser $local_scripts_DIR

    [[ -e ${local_scripts_DIR}/QC.sh ]] ||\
        ln -s ${SOURCEBASE}/QC_Process/QC.sh ${local_scripts_DIR}/QC.sh
    [[ -e ${local_scripts_DIR}/revert_prep_for_shipping_to_eu ]] ||\
        ln -s ${codebase}/revert_prep_for_shipping_to_eu\
     ${local_scripts_DIR}/revert_prep_for_shipping_to_eu 

    echo 'Verifying you have a home bin dir. And that QC / other scripts are present'
    find ${local_scripts_DIR} -exec ls -li --full-time {} \;

    echo 'Verifying that the correct Run Quality Control icon is in place...'
    (find ${SOURCEBASE}/QC_Process -iname 'Quality*' -exec md5sum {} \; ;\
        find ${SOURCEBASE}/Development/Master_${address_len} -iname 'Quality*' -exec md5sum {} \; ;\
        find ${HOME}/Desktop -iname 'Quality*' -exec md5sum {} \;) |grep -v '\.svn' |sort

    echo 'Done with Integrity Check'

    return 0
}

Swap_check() {

    Pauze 'Verifying (absence of) local UUID reference for swap in fstab.'
    declare -ix RCxU=0
    (date +'%s.%N';grep -P 'UUID.+swap' /etc/fstab;RCxU=$?)\
	|tee $filepath_swap_mess
    if [ $RCxU -eq 0 ]
    then
	(date +'%s.%N';echo 'fstab cAnNoT gO oN iMaGe wItH lOcAl UUID reference')\
	    |tee -a $filepath_swap_mess
    fi

    Pauze 'Verify swap off'
    sudo swapoff --all --verbose
    Pauze 'Verify swap on'
    sudo swapon --all --verbose

}

Install_Remove_requested_packages() {

    case $distro_generia in
        mint)
            Pauze 'WARNING,Ensure backports in /etc/apt/sources.list (or sources.d/)' 
            ;;
        *)
            Pauze 'Assuming Backports are automatically included'
            ;;
    esac

    Pauze 'Install necessary packages'
    RCxPK=0
    Install_packages_from_file_list $pathname_packages_list || RCxPK=$?
    #[[ $RCxPK -ne 0 ]] && Pauze 'Problems Installing Packages:'$RCxPK

    if [ $address_len -eq 64 ]
    then
        grep -o -P '^OnlyShowIn=.*MATE' /usr/share/applications/screensavers/*.desktop
        Pauze 'Mate Desktop able to access xscreensavers for ant spotlight?'
    fi

    return 0
}

#This_script_dir=$(dirname $0)
#for pkg_file in $(find $This_script_dir -maxdepth 1 -type f -name 'Packages*')

Install_packages_from_file_list() {
    local package_list_file=$1
    RCz=0

    declare hold_active_packages=/tmp/Packages_listed
    (
    for pkg_info_csv in $(grep -v '^#' $package_list_file)
    do
	echo $pkg_info_csv
        #Process_package $pkg_info_csv;RCa=$?
        #if [ $RCa -gt 0 ]
        #then
        #    echo 'Problem with package '$pkg_name
        #fi
    done
    ) |tee $hold_active_packages
    vim $hold_active_packages
    #${codebase}/List_o_packages.pl $package_list_file || echo 'No such program'

    return $RCz
}

Establish_ppa_repo_sourcefile() {
    local pkg_name=$1
    shift;ppa_name=$@

    search_ppa_name=$(echo $ppa_name|tr '/' '-')
    Pauze 'Beginning search for source.d ppa '$search_ppa_name'...'
    RCxRo=1
    find /etc/apt/sources.list.d/ -type f|grep $search_ppa_name && RCxRo=$?
    if [ $RCxRo -eq 0 ]
    then
        read -p'Found ppa, returning. <ENTER(t=8)>' -t8
        return 0
    fi
    apt_repo_name='ppa:'$ppa_name
    echo -n $apt_repo_name
    read -p' <Add to APT Repos?>' -a ADD_PPA_ARR || return 4
    [[ ${#ADD_PPA_ARR[*]} -eq 0 ]] && return 0
    if [ ${ADD_PPA_ARR[0]} == 'Y' ]
    then
        if [ $live_run != 'Y' ]
        then
            Pauze 'DRY RUN: adding repo '$apt_repo_name
            return 0
        fi

        sudo add-apt-repository $apt_repo_name || return $?
        return 0

    else
        Pauze 'Add repo '$apt_repo_name' later...'
        return 1
    fi

    return $?
}

Pkg_by_distro_session() {
    distro_session=$1

    Pkg_purge() {
       echo -n $pkg_name' '
       declare -a PUR_ARR=('Y')
       if [ $PUR_ALL == 'N' ]
       then
           read -p'<Purge?>' -a PUR_ARR || return 0
       fi
       [[ ${#PUR_ARR[*]} -eq 0 ]] && return 0
       if [ ${PUR_ARR[0]} == 'Y' ]
       then
           Apt_purge $pkg_name || return $?
       fi
   }
   Pkg_add() {
       echo -n $pkg_name' '
       declare -a ADD_ARR=('Y')
       if [ $ADD_ALL == 'N' ]
       then
           read -p'<Install/Upgrad3(Y|n)?>' -a ADD_ARR || return 0
       fi
       [[ ${#ADD_ARR[*]} -eq 0 ]] && return 0
       if [ ${ADD_ARR[0]} == 'Y' ]
       then
           Apt_install $pkg_name || return $?
       fi
   }
   case $distro_session in
       NONE)
           Pkg_purge ||return $?
           ;;
       ALL)
           Pkg_add || return $?
           ;;
       $distro_generia)
           Pkg_add || return $?
           ;;
       *)
	   echo 'Unknown Distro Generic Description '$distro_session
	   return 4
	   ;;
   esac

   return 1
}

Apply_custom_config() {

    case $distro_generia in
        ubuntu|mint)
            echo 'Run BPR Code'
            [[ -f ${codebase}/BPR_custom_prep.sh ]] &&\
                ${codebase}/BPR_custom_prep.sh
            Pauze "Run BPR: Last return code: $?"
            ;;
        *)
            Pauze "Don't need to run BPR additions for "$distro_generia' ('$DISTRO_NAME')'
            ;;
    esac

    return 0
}
Check_Setup_wallpaper() {

    # 64 bit : #0df2c6, #04227e
    [[ $DISTRO_NAME == 'lubuntu' ]] &&\
        sys_dir_wallpaper='/usr/share/lubuntu/wallpapers'
    sys_path_wallpaper=${sys_dir_wallpaper}/$filename_wallpaper
    if [[ -e $sys_path_wallpaper ]]
    then
        wallpaper_was_setup='Y'
        return 0
    fi

    [[ -d $sys_dir_wallpaper ]] || return 5
    [[ -f $src_path_wallpaper ]] || return 6

    if [ $live_run != 'Y' ]
    then
        Pauze 'DRY RUN: Would run cp -iv '${src_path_wallpaper}' '${sys_dir_wallpaper}'/'
        return 0
    fi

    Answer='Y'
    Pause_n_Answer 'Y|N'\
        'WARN,Copy '$filename_wallpaper' to '$sys_dir_wallpaper'?'
    if [ "${Answer}." == 'Y.' ]
    then
        sudo cp -iv $src_path_wallpaper ${sys_dir_wallpaper}/\
	    || return 7
        return 0
    fi

    return 1
}

Report_Check_Setup_wallpaper() {
    local RCi=$1

    [[ $live_run == 'Y' ]] || return 0

    case $RCi in
        0)
            [[ $wallpaper_was_setup == 'N' ]] && echo 'Wallpaper successfully setup'
            Pauze 'Wallpaper is in place:'$sys_path_wallpaper
            ;;
        1)
            Pauze 'WARNING, wallpaper setup will be done later...'
            ;;
        6)
            Pauze 'Invalid wallpaper source pathname '$src_path_wallpaper
            ;;
        5)
            Pauze 'Invalid wallpaper System Location: '$sys_dir_wallpaper
            ;;
        7)
            Pauze 'Cannot copy wallpaper to '$sys_dir_wallpaper
            ;;
        *)
            Pauze 'Invalid code:'${RCi}' Wallpaper report'
            ;;
    esac
    return 0
}

Launch_virtual_greybeard() {

    for Count in $(seq 1 5)
    do
        echo -ne "\n"
    done
    Pauze 'Lauching Virtual Greybeard'
    vrms
    Pauze '/\Please Purge Non-Free Stuff IF NEEDED/\'

    return 0
}

Cleanup_nouser_nogroup() {
    Mark_nouser_nogroup_fix_run=$1

    [[ -e $Mark_nouser_nogroup_fix_run ]] && return 0

    sudo find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -uid 1000\
        -nouser -exec chown -c root {} \; & PIDnu=$!
    sudo find /var/ /home/ /usr/ /root/ /lib/ /etc/ /dev/ /boot/ -not -gid 1000\
        -nogroup -exec chgrp -c root {} \; & PIDng=$!
    (while [ ! -e $Mark_nouser_nogroup_fix_run ];do sleep 30;ps -ef |awk '{print $2}' |egrep "$PIDnu|$PIDng" >/dev/null||touch $Mark_nouser_nogroup_fix_run;done;chmod -c 600 $Mark_nouser_nogroup_fix_run || logger -t 'Prepare2Image' 'Problem concluding Nouser Nogroup fix') &

    return 0
}

# -*- Execution continues here. M-ainline (below) invokes driving function -*-
set -u
declare -r HOLDIFS=$IFS 2>/dev/null
This_script=$(basename $0)
declare -rx Messages_O=$(mktemp -t "${This_script}_log.XXXXX")
declare -rx Errors_O=$(mktemp -t "${This_script}_err.XXXXX")

pathname_packages_list=${codebase}'/Packages'
filename_wallpaper='FreeIT.png'
src_path_wallpaper=${codebase}/$filename_wallpaper
sys_dir_wallpaper='/usr/share/backgrounds'
wallpaper_was_setup='N'
aptcache_needs_update='Y'
refresh_updatedb='N'
refresh_svn='N'
refresh_git='Y'
ADD_ALL='Y'
PUR_ALL='Y'
live_run='N'
batch_run='N'
realuser=${HOME#/home/}
filepath_swap_mess=${HOME}'/Prepare_swapfile_action'
sudo touch $filepath_swap_mess
sudo chown -c $realuser $filepath_swap_mess
cat /dev/null >$filepath_swap_mess
declare distro_generia='nodistro'

# -*- Process any command line Options -*-
Optvalid='APbDn:RuVGh'
while getopts $Optvalid OPT
do
    case $OPT in
        A)
            ADD_ALL='N'
            ;;
        P)
            PUR_ALL='N'
            ;;
        D)
            live_run='Y'
            ;;
        b)
            batch_run='Y'
            ;;
        n)
            Set_Confirm_distro_name $OPTARG;RCx1=$?
            [[ $RCx1 -gt 11 ]] && exit $RCx1
            ;;
        R)
            aptcache_needs_update='N'
            ;;
        u)
            refresh_updatedb='Y'
            ;;
        V)
            refresh_svn='Y'
            ;;
        G)
            refresh_git='N'
            ;;
        h)
            echo $This_script
	    echo "D makes live_run='Y'"
            echo "A makes ADD_ALL='N'"
            echo "P makes PUR_ALL='N'"
            echo "b makes batch_run='Y'"
            echo "n sets :Distro Name:"
            echo "R makes aptcache_needs_update='N'"
            echo "u makes refresh_updatedb='Y'"
            echo "V makes refresh_svn='Y'"
            echo "G makes refresh_git='N'"
            #Optvalid='APbDn:RuVGh'
            echo '(Match up with '$Optvalid')'
            exit 0
            ;;
        *)
            echo 'Unknown option: '${OPT}'. Exiting.'
            exit 8
            ;;
    esac
done

echo -ne "\n\n\e[1;31;40m"\
'*---------------------------------------------------------------*'
echo -e "\e[0m"

# -x = let child processes inherit
# -r = make value permanent (read-only)
declare -x aptcache_needs_update
declare -x refresh_svn
declare -x refresh_git
declare -r ADD_ALL
declare -r PUR_ALL
declare -rx batch_run
[[ $batch_run == 'Y' ]] || Pauze 'Interactive Run Selected'

echo '$SOURCEBASE='$SOURCEBASE
echo '$codebase='$codebase
echo '$realuser='$realuser
echo '$pathname_packages_list'=$pathname_packages_list
echo '$filename_wallpaper'=$filename_wallpaper
echo '$src_path_wallpaper'=$src_path_wallpaper
echo '$sys_dir_wallpaper'=$sys_dir_wallpaper
echo '$aptcache_needs_update'=$aptcache_needs_update
echo '$refresh_updatedb'=$refresh_updatedb
echo '$refresh_svn'=$refresh_svn
echo '$refresh_git'=$refresh_git
echo '$ADD_ALL'=$ADD_ALL
echo '$PUR_ALL'=$PUR_ALL

declare -rx live_run
[[ $live_run == 'Y' ]] && echo 'LIVE RUN Selected. System files COULD be changed!'
read -p'Confirm Selections <ENTER> ... or LEAVE <Control-C>'

Mainline

[[ -z $PIDnu ]] || echo 'Check on process '$PIDnu
[[ -z $PIDng ]] || echo 'Check on process '$PIDng

# Make the version-controlled tree - SOURCEBASE --

#PKGS='lm-sensors hddtemp ethtool gimp firefox 
#  dialog xscreensaver-gl libreoffice aptitude vim
#  flashplugin-installer htop inxi vrms mintdrivers gparted terminator hardinfo'

    #Pauze 'Confirm no medibuntu in apt sources'
    #egrep -v '^\s*(#|$)' /etc/apt/sources.list |grep medi && sudo vi /etc/apt/sources.list
#if [ $(whoami) == 'root' ]
#if [ $(id -u) -eq 0 ]

