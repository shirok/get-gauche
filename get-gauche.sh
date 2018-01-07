#!/bin/bash

set -e

API=https://practical-scheme.net/gauche/releases

# Ensure Gauche availability
# https://github.com/shirok/get-gauche/README

function usage() {
    cat <<"EOF"
Usage:
    get-gauche.sh [--system|--home|--current|--prefix PREFIX][--auto]
                  [--version VERSION][--check-only][--force][--list]
Options:
    --auto
        When get-gauche.sh finds Gauche needs to be installed, it proceed
        to download and install without asking the user.  By default,
        the user is asked before download begins.

    --check-only
        detect Gauche and report result, but not to attempt download
        and install.

    --current
        install Gauche under the current directory.
        Equivalent to --prefix `pwd`.

    --force
        do not check if Gauche has already installed or not, and always
        download ans install one.

    --home
        install Gauche under the user's home directory.
        Equivalent to --preifx $HOME.

    --list
        show valid Gauche versions for --version option and exit.  No
        other operations are performed.

    --prefix PREFIX
        install Gauche under PREFIX.  The gosh executable is in PREFIX/bin,
        binary libraries are in PREFIX/lib, etc.

    --system
        install Gauche under system directory.
        Equivalen to --prefix /usr.

    --version VERSION
        specify the desired version of Gauche.  VERSION can be a version
        string (e.g. '0.9.5'), or either 'latest' or 'snapshot'.  The word
        'latest' picks the latest release.  The word 'snapshot' picks the
        newest snapshot tarball if there's any newer than the latest
        release, or the latest release otherwise.
        By default, 'latest' is assumed.
EOF
}

function cleanup {
    if [ -d "$WORKDIR" ]; then
        rm -rf "$WORKDIR"
    fi
}

trap cleanup EXIT

function do_list {
    curl -f $API/.txt
    exit 0
}

function do_check_gosh {
    if [ $prefix = `pwd` ]; then
        PATH=`pwd`/bin:$PATH
    fi
    gosh_path=`which gosh || :`
}

function do_fetch_and_install {
    CWD=`pwd`
    WORKDIR=`mktemp -d $CWD/tmp.XXXXXXXX`

    cd $WORKDIR
    if ! curl -f -L -o Gauche-$desired_version.tgz $API/$desired_version.tgz; then
        echo "Failed URL:" $API/$desired_version.tgz
        exit 1
    fi
    tar xf Gauche-$desired_version.tgz
    # The actual directory name may differ when $version is latest or snapshot
    cd Gauche-*
    ./configure --prefix=$prefix
    make -j
    make -s check
    make install

    echo "################################################################"
    echo "#  Gauche installed under $prefix/bin"
    echo "################################################################"
}

function compare_version {
    $gosh_path -b <<EOF
(use gauche.version)
(if (version>? "$1" "$2")
  (print "GT")
  (print "LE"))
EOF
}

################################################################
# main entry point
#

prefix=$HOME
desired_version=latest
check_only=no
force=no

while test $# != 0
do
    case $1 in
        --*=?*)
            option=`expr "X$1" : 'X\([^=]*\)='`
            optarg=`expr "X$1" : 'X[^=]*=\(.*\)'`
            extra_shift=:
            ;;
        --*=)
            option=`expr "X$1" : 'X\([^=]*\)='`
            optarg=
            extra_shift=:
            ;;
        *)
            option=$1
            optarg=$2
            extra_shift=shift
            ;;
    esac
    
    case $option in
        --list)     do_list;;

        --system)   prefix=/usr ;;
        --home)     prefix=$HOME ;;
        --current)  prefix=`pwd` ;;
        --prefix)   prefix=$optarg; $extra_shift ;;

        --version)  desired_version=$optarg; $extra_shift ;;
        
        --auto)     auto=yes ;;
        --check-only) check_only=yes ;;
        --force)      force=yes ;;

        --static)   staticlib=yes ;;

        *) usage; exit 1;;
    esac
    shift
done

do_check_gosh

#
# If --check-only, just report the check result and exit
#
if [ "$check_only" = yes ]; then
    if [ -z $gosh_path ]; then
        echo "Gauche not found"
        exit 1
    else
        echo "Found gosh in $gosh_path"
        $gosh_version -V
        exit 0
    fi
fi

#
# Resolve 'latest' and 'snapshot' versions to the actual version
#
case $desired_version in
    latest)   desired_version=`curl -f $API/latest.txt 2>/dev/null`;;
    snapshot) desired_version=`curl -f $API/snapshot.txt 2>/dev/null`;;
esac

#
# Compare with current version
#
if [ ! -z "$gosh_path" ]; then
   current_version=`$gosh_path -E "print (gauche-version)" -Eexit`
fi

if [ -z "$current_version" ]; then
    echo "Gauche is not found on the system."
    need_install=yes
else
    cmp=`compare_version $desired_version $current_version`
    case $cmp in
        GT) echo "You have Gauche $current_version."
            need_install=yes;;
        LE) echo "You already have Gauche $current_version.";;
    esac
fi

#
# Proceed to install
#
if [ "$force" = yes -o "$need_install" = yes ]; then
    if [ "$auto" != yes ]; then
      echo -n "Install Gauche $desired_version under $prefix? [y/N]: "
      read ans
      case "$ans" in
          [yY]*) ;;
          *) exit 0;;
      esac
    fi
    echo "Start installing Gauche $desired_version..."
    do_fetch_and_install
fi
