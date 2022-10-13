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
  print_me err     "\t-d, --distro <name>    " ; print_me info "\tSpecify distro to build for a given board\n"
  print_me err     "\t-f, --flash <blockdev> " ; print_me info "\tFor flashing the devices eMMC over usb\n"
  print_me err     "\t-h, --help             " ; print_me info "\tSee this message\n"
}


print_buildable_machines() {
  machines=("$@")

  print_me warn "List of buildable images\n"
  for machine in "${machines[@]}"; do
    print_me warn "\t[*] ${machine}\n"
  done
}


display_machine_err() {
  machines=(udoo-bolt-live-usb udoo-bolt-emmc)

  [[ -n "${MACHINE}" ]] || {
    print_me err "[x] Must enter a machine name\n"
    print_buildable_machines "${machines[@]}"
    echo ; help_msg $0 ; return $FAILURE
  }

  for machine in "${machines[@]}"; do
    if [[ "${machine}" == "${MACHINE}" ]]; then
      return $SUCCESS
    fi
  done

  print_me err "[x] error: ${MACHINE} isn't in the list of buildable images\n"
  print_buildable_machines "${machines[@]}"

  return $FAILURE
}


display_flash_err() {
  flash_blockdev=$1

  [[ -n "${flash_blockdev}" ]] || {
    print_me err "[x] error: Must pass file to flash\n"
    return $FAILURE
  }

  return $SUCCESS
}


print_distro_configs() {
  distros=("$@")

  print_me warn "List of distro configs to create images with\n"
  for distro in "${distros[@]}"; do
    print_me warn "\t[*] ${distro}\n"
  done
}


display_distro_err() {
  distros=(underview north-star-demo)

  [[ -n "${DISTRO}" ]] || {
    print_me err "[x] Must enter a distro name. If flag not specified underview is used.\n"
    print_distro_configs "${distros[@]}"
    echo ; help_msg $0 ; return $FAILURE
  }

  for distro in "${distros[@]}"; do
    if [[ "${distro}" == "${DISTRO}" ]]; then
      return $SUCCESS
    fi
  done

  print_me err "[x] error: ${DISTRO} isn't in the list of distro configs\n"
  print_distro_configs "${distros[@]}"

  return $FAILURE
}
