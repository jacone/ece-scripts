################################################################################
#
# VOSA - build server script - customer x
#
################################################################################

# customer
CUSTOMER=test

# date used for .ear naming 
DATE=`date +%F_%H%M`

# svn information
SVN_BASE=https://mysvnserver.com/svn/MYPROJECT/
SVN_PATH=

SVN_USER=myproject-build-user
SVN_PASSWORD=yesyouwouuldlikethatwouldntyou

# release label for .ear naming - default: trunk
RELEASE_LABEL=trunk

# clean up customer home
function home_preparation {

  rm ~/plugins/*
  rm ~/engine
  rm ~/assemblytool/publications/*
  rm ~/assemblytool/lib/*
  rm -rf src
  mkdir src
  #TODO: make a place where everything common to all ears go.
  ln -s /opt/escenic/assemblytool/lib/java_memcached-release_2.0.1.jar assemblytool/lib/

}

# checkout customer project
function svn_checkout {

  type=$1

  if [ "$type" = "trunk" ]; then
    SVN_PATH=trunk
    RELEASE_LABEL=$type
  elif [ "$type" = "branch" ]; then
    SVN_PATH=branches/$2
    RELEASE_LABEL=$type-$2
  elif [ "$type" = "tag" ]; then
    SVN_PATH=tags/$2
    RELEASE_LABEL=$type-$2
  fi

  if [ "$SVN_PATH" = "" ]; then
    echo "No svn path chosen! Will use 'trunk'."
    SVN_PATH=trunk
  fi

  echo "Initiating svn checkout of $SVN_PATH"
  svn checkout --username=$SVN_USER --password=$SVN_PASSWORD $SVN_BASE$SVN_PATH src/.

}

# parse version based on property from src/pom.xml
function parse_version {
  export $1=`sed "/<$2>/!d;s/ *<\/\?$2> *//g" ~/src/pom.xml | tr -d $'\r' `
}

# symlink component from /opt/vosa/.
function symlink_distribution {
  ln -s /opt/vosa/$1 ~/$2
}

function symlink_ece_components {

  # Version - Escenic Content Engine
  parse_version ENGINE_VERSION vosa.engine.version
  symlink_distribution engine/engine-$ENGINE_VERSION engine

  # Version - Geo Code
  parse_version GEOCODE_VERSION vosa.geocode.version
  symlink_distribution plugins/geocode-$GEOCODE_VERSION plugins/geocode

  # Version - Poll
  parse_version POLL_VERSION vosa.poll.version
  symlink_distribution plugins/poll-$POLL_VERSION plugins/poll

  # Version - Menu Editor
  parse_version MENU_EDITOR_VERSION vosa.menu-editor.version
  symlink_distribution plugins/menu-editor-$MENU_EDITOR_VERSION plugins/menu-editor

  # Version - XML Editor
  parse_version XML_EDITOR_VERSION vosa.xml-editor.version
  symlink_distribution plugins/xml-editor-$XML_EDITOR_VERSION plugins/xml-editor

  # Version - Analysis Engine
  parse_version ANALYSIS_ENGINE_VERSION vosa.analysis-engine.version
  symlink_distribution plugins/analysis-engine-$ANALYSIS_ENGINE_VERSION plugins/analysis-engine

  # Version - Forum
  parse_version FORUM_VERSION vosa.forum.version
  symlink_distribution plugins/forum-$FORUM_VERSION plugins/forum

  # Version - Widget Framework Common
  parse_version WIDGET_FRAMEWORK_COMMON_VERSION vosa.widget-framework-common.version
  symlink_distribution plugins/widget-framework-common-$WIDGET_FRAMEWORK_COMMON_VERSION plugins/widget-framework-common

}

# symlink .war files from target/
function symlink_target {

  # global classpath
  for f in $(ls -d ~/src/vosa-assembly/target/lib/*);
    do ln -s $f ~/assemblytool/lib;
  done

  # publications
  for f in $(ls -d ~/src/vosa-assembly/target/wars/*);
    do ln -s $f ~/assemblytool/publications;
  done

}

function release {

  home_preparation

  svn_checkout $1 $2
  revision=`svn info src | grep -i Revision | awk '{print $2}'`

  symlink_ece_components

  cd src
  mvn clean package

  cd vosa-assembly/target
  unzip vosa-assembly.zip

  symlink_target

  cd ~/assemblytool
  ant -q ear -DskipRedundancyCheck=true

  cp dist/engine.ear ~/releases/$CUSTOMER-$RELEASE_LABEL-rev$revision-$DATE.ear

}

################################################
# VOSA - Build Server Script
################################################

case "$1" in

release)

  release $2 $3
  ;;

*)
  echo $"Usage: $0 {release}"
  exit 2
esac

exit $?

