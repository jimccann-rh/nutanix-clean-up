#!/bin/bash
PATH=~/prism/cli:/usr/local/nutanix/bin:$PATH

function usage {
      echo "Usage:"
      echo "    $0  [-h] -c <storage container Uuid, defaults to Uuid of container 'test'> [-d]"
      echo "Using -d deletes VGs"
      exit 1
}

while getopts "hd?:c" opt; do
  case ${opt} in
    h)
      usage
      ;;
    c)
      CONTAINER_UUID="${OPTARG}"
      ;;
    d)
      DELETE_VG=1
      echo "Running in delete mode"
      ;;
    \?)
      echo "Invalid Option: -$OPTARG" 1>&2
      usage
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

CONTAINER_UUID="a4b9982f-f55f-458c-88a2-c8d0547b174f"
#CONTAINER_UUID="d6d4b5be-74d0-4a18-8313-d2197b19582f"

if [[ -z $DELETE_VG ]]; then
  echo "Running in dry run"
fi

res=`acli vg.list | grep ^pvc-`
readarray -t lines <<< "$res"
COUNTER=0
for line in "${lines[@]}"
do
  echo $line
  # line is in "$name $uuid" form.
  for vg in $line
  do
    # Get storage container
    cont=`acli vg.get $vg | grep container_uuid`
    echo $cont
    IFS=' ' read -a myarray <<< "$cont"
    cont=`eval echo ${myarray[1]}`
    echo "container : $cont containeruuid: $CONTAINER_UUID"
    if [[ $cont != $CONTAINER_UUID ]]; then
      echo "Skip $vg in container ${myarray[1]} containeruuid: $CONTAINER_UUID"
      continue
    fi
    count=$(grep ^pvc- <<< $vg | wc -l)
    if [[ $count == 1 ]]; then
      continue
    fi
    # Delete PVC by UUID
    echo "Deleting VG $vg"
    iqn=`acli vg.get $vg | grep external_initiator_name`
    echo $iqn
    IFS=' ' read -a myarray <<< "$iqn"
    echo "iqn : ${myarray[1]}"
    if [[ -n $iqn ]]; then
      cmd="acli vg.detach_external $vg initiator_name=${myarray[1]}"
      if [[ -z $DELETE_VG ]]; then
        echo "Dry Run : $cmd"
      else
        $cmd
      fi
    fi
    cmd="acli -y vg.delete $vg"
    if [[ -z $DELETE_VG ]]; then
      echo "Dry Run : $cmd"
    else
      $cmd &
    fi
    let COUNTER++
    echo ""
   done
done
echo "Total VGs on this cluster = $(acli vg.list | wc -l)"
echo "Total VGs starting with prefix pvc = ${#lines[@]}"
echo "Number of VGs to be deleted = $COUNTER"

