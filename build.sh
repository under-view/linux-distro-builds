#!/bin/bash

SUCCESS=0
FAILURE=1

CDIR="$(pwd)"
WORK_DIR="${CDIR}/working"
BUILD_DIR="${WORK_DIR}/underview-os"
IMAGES_DIR="${WORK_DIR}/images"

IMAGE_TYPE="core-image-base"

export MACHINE=""

# User space memory allocation is allowed to over-commit memory (more than
# available physical memory) which can lead to out of memory errors
# The out of memory (OOM) killer kicks in and selects a process to kill to retrieve some memory.
# Thus why we see the bellow error at random points of the build
#     x86_64-underview-linux-g++: fatal error: Killed signal terminated program cc1plus
# Lowering BBTHREADS and MTHREADS ensures the system doesn't run out of memory when building
core_count=$(nproc)
export PARALLEL_MAKE="-j $((core_count / 2))"
export BB_NUMBER_THREADS=$((core_count / 2))
export BB_ENV_PASSTHROUGH_ADDITIONS="$BB_ENV_PASSTHROUGH_ADDITIONS MACHINE PARALLEL_MAKE BB_NUMBER_THREADS"


###########################################
# Just makes log output colorful
###########################################
print_me() {
  case $1 in
  success) printf "\e[32;1m" ;;
  err)     printf "\e[31;1m" ;;
  info)    printf "\e[34;1m" ;;
  warn)    printf "\e[33;1m" ;;
  *)       return $FAILURE
  esac

  # print output and reset terminal color
  printf "${@:2}" ; printf "\x1b[0m"
}


#####################################################
# Just a help message
#####################################################
help_msg() {
  fname=$1

  print_me success "Usage: ${fname} [options]\n"
  print_me warn    "Example: ${fname} --machine udoo-bolt-emmc\n"
  print_me info    "Options:\n"
  print_me err     "\t-m, --machine <name>   " ; print_me info "\tSpecify a machine to build for a given board\n"
  print_me err     "\t-f, --flash <blockdev> " ; print_me info "\tFor flashing the devices eMMC over usb\n"
  print_me err     "\t-h, --help             " ; print_me info "\tSee this message\n"
}


enter_environment() {
  source "${WORK_DIR}/openembedded-core/oe-init-build-env" "${BUILD_DIR}"
  [[ $? -ne 0 ]] && return $FAILURE

  ln -sf "${WORK_DIR}/meta-underview/conf/local.conf.sample" "${BUILD_DIR}/conf/local.conf"

  cd "${CDIR}"

  return $SUCCESS
}


# Add layers to bblayers.conf if they don't already exsists
add_layers() {
  bblayers=$(cat < "${BUILD_DIR}/conf/bblayers.conf" | grep meta-underview)
  [[ -n "${bblayers}" ]] && return $SUCCESS

  cd "${BUILD_DIR}"

  bitbake-layers add-layer ../meta-openembedded/meta-oe || return 1
  bitbake-layers add-layer ../meta-openembedded/meta-python || return 1
  bitbake-layers add-layer ../meta-openembedded/meta-networking || return 1
  bitbake-layers add-layer ../meta-wayland || return 1
  bitbake-layers add-layer ../meta-amd/meta-amd-bsp || return 1
  bitbake-layers add-layer ../meta-udoo-bolt || return 1
  bitbake-layers add-layer ../meta-underview || return 1

  return $SUCCESS
}


build() {
  bitbake "${IMAGE_TYPE}" || return $FAILURE

  return $SUCCES
}


copy_final_artifacts() {
  mkdir -pv "${IMAGES_DIR}"

  copy_final_artifacts_dir="${BUILD_DIR}/tmp/deploy/images/${MACHINE}"

  cp "${copy_final_artifacts_dir}/${IMAGE_TYPE}-${MACHINE}.wic.bmap" "${IMAGES_DIR}" || return $FAILURE
  cp "${copy_final_artifacts_dir}/${IMAGE_TYPE}-${MACHINE}.wic.gz"   "${IMAGES_DIR}" || return $FAILURE
  cp "${copy_final_artifacts_dir}/${IMAGE_TYPE}-${MACHINE}.wic"      "${IMAGES_DIR}" || return $FAILURE

  print_me success "\ncopied ${IMAGE_TYPE}-${MACHINE}.wic.bmap to ${IMAGES_DIR}\n"
  print_me success "copied ${IMAGE_TYPE}-${MACHINE}.wic.gz to ${IMAGES_DIR}\n"
  print_me success "copied ${IMAGE_TYPE}-${MACHINE}.wic to ${IMAGES_DIR}\n"

  return $SUCCES
}


build_image() {
  enter_environment || return $FAILURE
  add_layers || return $FAILURE
  build || return $FAILURE
  copy_final_artifacts || return $FAILURE

  return $SUCCESS
}


flash_image() {
  flash_blockdev=$1
  return $SUCCESS
}


# If no arguments supplied run help function
[[ $# -eq 0 ]] && { help_msg $0 ; exit $FAILURE ; }

flash_blockdev=""

for ((arg=1; arg<=$#; arg++)); do
  arg_to_flag=$((arg+1))
  case "${!arg}" in
    -m|--machine)
      MACHINE="${!arg_to_flag}"
      ((arg++))
      ;;
    -f|--flash)
      flash_blockdev="${!arg_to_flag}"
      ((arg++))
      ;;
    -h|--help)
      help_msg $0
      exit $FAILURE
      ;;
    *)
      $0 --help
      exit $FAILURE
      ;;
  esac
done


[[ -n "${MACHINE}" ]] || {
  print_me err "[x] Must enter machine name\n"
  help_msg $0
  exit $FAILURE
}


[[ -n "${flash_blockdev}" ]] && {
  flash_image "${flash_blockdev}"
} || {
  build_image
}

exit $SUCCESS
