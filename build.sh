#!/bin/bash

SUCCESS=0
FAILURE=1

CDIR="$(pwd)"
WORK_DIR="${CDIR}/working"
BUILD_DIR="${WORK_DIR}/underview-os"
IMAGES_DIR="${WORK_DIR}/images"

IMAGE_TYPE="core-image-base"

export MACHINE=""
export DISTRO="underview"

source "${CDIR}/helpers.sh"

# User space memory allocation is allowed to over-commit memory (more than
# available physical memory) which can lead to out of memory errors
# The out of memory (OOM) killer kicks in and selects a process to kill to retrieve some memory.
# Thus why we see the bellow error at random points of the build
#     x86_64-underview-linux-g++: fatal error: Killed signal terminated program cc1plus
# Lowering BBTHREADS and MTHREADS ensures the system doesn't run out of memory when building
core_count=$(nproc)
export PARALLEL_MAKE="-j $((core_count / 2))"
export BB_NUMBER_THREADS=$((core_count / 2))
export BB_ENV_PASSTHROUGH_ADDITIONS="$BB_ENV_PASSTHROUGH_ADDITIONS MACHINE DISTRO PARALLEL_MAKE BB_NUMBER_THREADS"


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
  mkdir -p "${IMAGES_DIR}"

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
  [[ -d "${IMAGES_DIR}" ]] || {
    print_me err "[x] ${IMAGES_DIR}: does not exist. Must run build script.\n"
    return $FAILURE
  }

  flash_blockdev=$1
  sudo umount "${flash_blockdev}"* 2>/dev/null

  sudo bmaptool copy --bmap \
                "${IMAGES_DIR}/${IMAGE_TYPE}-${MACHINE}.wic.bmap" \
                "${IMAGES_DIR}/${IMAGE_TYPE}-${MACHINE}.wic.gz" \
                "${flash_blockdev}" || return $FAILURE

  sudo eject "${flash_blockdev}"
  print_me warn "ejecting --> ${flash_blockdev}\n"

  return $SUCCESS
}


# If no arguments supplied run help function
[[ $# -eq 0 ]] && { help_msg $0 ; exit $FAILURE ; }

flash_blockdev=""

for ((arg=1; arg<=$#; arg++)); do
  arg_passed_to_flag=$((arg+1))
  case "${!arg}" in
    -m|--machine)
      MACHINE="${!arg_passed_to_flag}"
      display_machine_err || exit $FAILURE
      ((arg++))
      ;;
    -f|--flash)
      flash_blockdev="${!arg_passed_to_flag}"
      display_flash_err "${flash_blockdev}" || exit $FAILURE
      ((arg++))
      ;;
    -d|--distro)
      DISTRO="${!arg_passed_to_flag}"
      display_distro_err || exit $FAILURE
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

IMAGES_DIR="${IMAGES_DIR}/${DISTRO}"

[[ -n "${flash_blockdev}" ]] && {
  flash_image "${flash_blockdev}" || exit $FAILURE
} || {
  build_image || exit $FAILURE
}

exit $SUCCESS
