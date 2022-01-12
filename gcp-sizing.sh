#!/bin/sh
projects=''
billing_account=''
billing_account_name=''
package="GCP Compute Sizing Report CLI"
output_folder=''

get_billing_account_name(){
  billing_account_name=$(gcloud beta billing accounts describe $billing_account --format="csv[no-heading](displayName)")
}

get_all_projects(){
  echo "Get Projects from Billing Account: $billing_account"
  # readarray -t projects < <(gcloud beta billing projects list --billing-account=$billing_account --format="csv(projectId)" | awk 'NR > 1')
  projects=$(gcloud beta billing projects list --billing-account=$billing_account --format="csv(projectId)" | awk 'NR > 1')
}

get_all_instances(){
  echo "Writing compute instances on project: $1 to logs"
  echo "$1,,,,," >> "$output_folder/instances.csv"
  gcloud compute instances list -q \
  --format="csv[no-heading](name,zone.basename(),machine_type.basename(),networkInterfaces.networkIP,networkInterfaces.accessConfigs[0].natIP,status)" \
  --project $1 >> "$output_folder/instances.csv"
}

get_all_sql_instances(){
  echo "Writing sql instances on project: $1 to logs"
  echo "$1,,,,,,,," >> "$output_folder/sql_instances.csv"
  gcloud sql instances list -q \
  --format="csv[no-heading](name,databaseVersion,gceZone,settings.tier,settings.dataDiskType,settings.dataDiskSizeGb,ipAddresses[0].ipAddress,failoverReplica.available,state)" \
  --project $1 >> "$output_folder/sql_instances.csv"
}

get_all_redis(){
  echo "Writing redis on project: $1 to logs"
  echo "$1,,,,,,,," >> "$output_folder/redis.csv"
  gcloud redis instances list -q \
  --format="csv[no-heading](displayName,redisVersion,currentLocationId,tier,memorySizeGb,connectMode,host,port,reservedIpRange,state)" \
  --region asia-southeast2 \
  --project $1 >> "$output_folder/redis.csv"
}

get_all_disks(){
  echo "Writing compute disks on project: $1 to logs"
  echo "$1,,,," >> "$output_folder/disks.csv"
  gcloud compute disks list -q --format="csv[no-heading](name,zone.basename(),size_gb,type,status)" --project $1 >> "$output_folder/disks.csv"
}

get_all_addresses(){
  echo "Writing ip addresses on project: $1 to logs"
  echo "$1,,,," >> "$output_folder/addresses.csv"
  gcloud compute addresses list -q --format="csv[no-heading](name,address,address_type,purpose,status)" --project $1 >> "$output_folder/addresses.csv"
}

write_directory(){
  output_folder=$(echo "$billing_account/$(date +"%d%m%y")")
  mkdir -p $output_folder
}

write_headers(){
  echo "PROJECT,NAME,ZONE,MACHINE_TYPE,INTERNAL_IP,EXTERNAL_IP,STATUS" >> "$output_folder/instances.csv"
  echo "PROJECT,NAME,ZONE,STORAGE_SIZE(GB),STORAGE_TYPE,STATUS" >> "$output_folder/disks.csv"
  echo "PROJECT,NAME,ADDRESS,ADDRESS_TYPE,PURPOSE,STATUS" >> "$output_folder/addresses.csv"
  echo "PROJECT,NAME,DATABASE_VERSION,LOCATION,TIER,STORAGE_TYPE,STORAGE_SIZE(GB),PRIMARY_ADDRESS,HIGH_AVAILABILITY,STATUS" >> "$output_folder/sql_instances.csv"
  echo "PROJECT,NAME,VERSION,LOCATION,TIER,MEMORY_SIZE(GB),CONNECTION_MODE,HOST,PORT,RESERVED_IP_RANGE,STATUS" >> "$output_folder/redis.csv"
}

report_all_projects(){
  get_billing_account_name
  get_all_projects
  write_directory
  write_headers
  for i in "${projects}"
  do
    get_all_instances $i
    get_all_addresses $i
    get_all_disks $i
    get_all_sql_instances $i
    get_all_redis $i
  done
}

if [ $# -eq 0 ]; then
    echo "No arguments provided. You must specify billing account to use."
    echo "Use -h arguments for more detail."
    exit 1
fi

while getopts 'b:h' flag; do
  case "${flag}" in
    b)
      billing_account="${OPTARG}"
      ;;
    h)
      echo "$package - Write GCP Instances, Disks, and Addresses to csv files"
      echo " "
      echo "$package [options] application [arguments]"
      echo " "
      echo "options:"
      echo "-h         show brief help"
      echo "-b         specify GCP billing account to use"
      exit 0
      ;;
    *)
      echo "Unexpected option ${flag}"
      echo "Use -h arguments for more detail."
      exit 1
      ;;
  esac
done

report_all_projects
