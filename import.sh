#!/bin/sh
# vim: ai:ts=8:sw=8:noet


# Global variables required by most requests
LANGUAGE="es"
BASE_PATH="https://api.themoviedb.org"



# V4 authentication
V4_READ_ACCESS_TOKEN=$(tail -n 1 .secrets)

V4_REQUEST_TOKEN=$(curl --silent \
        --header "authorization: Bearer ${V4_READ_ACCESS_TOKEN}" \
        --header "content-type: application/json;charset=utf-8" \
        --request POST "${BASE_PATH}/4/auth/request_token" \
        | jq -r '.request_token')

firefox "https://www.themoviedb.org/auth/access?request_token=${V4_REQUEST_TOKEN}"
echo "Accept and press any key to continue"
read none

V4_ACCESS_TOKEN=$(curl --silent \
        --header "authorization: Bearer ${V4_READ_ACCESS_TOKEN}" \
        --header "content-type: application/json;charset=utf-8" \
        --request POST "${BASE_PATH}/4/auth/access_token" \
        --data '{"request_token":"'${V4_REQUEST_TOKEN}'"}' \
        | jq -r '.access_token')



# V3 authentication
V3_API_KEY=$(head -n 1 .secrets)
V3_SESSION_ID=$(curl --silent \
        --header "Content-Type: application/json" \
        --request POST "${BASE_PATH}/3/authentication/session/convert/4?api_key=${V3_API_KEY}" \
        --data '{"access_token":"'${V4_ACCESS_TOKEN}'"}' \
        | jq -r '.session_id')



################################################################################
#
################################################################################
help() {
  echo " -f <Name of the .json file>"
}



################################################################################
#
################################################################################
find_account_id() {
  echo $(curl --silent \
    --request GET "${BASE_PATH}/3/account?api_key=${V3_API_KEY}&session_id=${V3_SESSION_ID}" \
    | jq -r '. | .id')
}



################################################################################
# $1 - Type
################################################################################
type_to_s() {
  if [ $1 -eq 1 ]
  then
    echo "tv"
  elif [ $1 -eq 2 ]
  then
    echo "movie"
  elif [ $1 -eq 3 ]
  then
    echo "movie"
  fi
}



################################################################################
# $1 - imdb ID
# $2 - Type
#   TV_SHOWS=1
#   MOVIES=2
#   DOCUMENTARY=3
################################################################################
find_id_by_imdb() {
  if [ $2 -eq 1 ]
  then
    curl --silent \
      --request GET "${BASE_PATH}/3/find/$1?api_key=${V3_API_KEY}&language=${LANGUAGE}&external_source=imdb_id" \
      | jq -r '. | .tv_results[0] | .id'
  elif [ $2 -eq 2 ]
  then
    curl --silent \
      --request GET "${BASE_PATH}/3/find/$1?api_key=${V3_API_KEY}&language=${LANGUAGE}&external_source=imdb_id" \
      | jq -r '. | .movie_results[0] | .id'
  elif [ $2 -eq 3 ]
  then
    curl --silent \
      --request GET "${BASE_PATH}/3/find/$1?api_key=${V3_API_KEY}&language=${LANGUAGE}&external_source=imdb_id" \
      | jq -r '. | .movie_results[0] | .id'
  fi
}



################################################################################
# $1 - List name
################################################################################
create_list() {
  curl --silent \
    --header "Content-Type: application/json" \
    --request POST "${BASE_PATH}/3/list?api_key=${V3_API_KEY}&session_id=${V3_SESSION_ID}" \
    --data '{"name":"'$1'", "description":"avillen", "language":"'${LANGUAGE}'"}' \
    | jq -r '.list_id'
}



################################################################################
# $1 - Number of items that will be imported (just to count)
# $2 - Type
# $3 - ID of the list where the item will be added
# $@ - IMDB ids to be imported
################################################################################
import_to_list() {
  N_ITEMS=$1
  TYPE=$2
  ID_LIST=$3
  shift
  shift
  shift

  i=1
  for imdb in $@; do
    ITEM_ID=$(find_id_by_imdb $imdb $TYPE)
    MEDIA_TYPE=$(type_to_s $TYPE)

    curl --silent \
      --header "authorization: Bearer ${V4_ACCESS_TOKEN}" \
      --header "content-type: application/json;charset=utf-8" \
      --request POST "${BASE_PATH}/4/list/${ID_LIST}/items" \
      --data '{"items":[{"media_id":"'${ITEM_ID}'","media_type":"'${MEDIA_TYPE}'"}]}' \
    | jq '. | .success'

    echo "${i}/${N_ITEMS}"
    i=$((i + 1))
    sleep 1
  done
}



################################################################################
# $1 - Number of items that will be imported (just to count)
# $2 - Type
# $@ - Rates json with id and rate to be imported
################################################################################
import_rates() {
  i=1

  N_ITEMS=$1
  TYPE=$2
  shift
  shift

  echo "$@" | jq -c '.' | while IFS= read -r line; do
    IMDB=$(echo $line | jq -r -j '.imdb')
    RATE=$(echo $line | jq -r -j '.rating')
    ITEM_ID=$(find_id_by_imdb $IMDB $TYPE)
    MEDIA_TYPE=$(type_to_s $TYPE)

    curl --silent \
      --header "Content-Type: application/json" \
      --request POST "${BASE_PATH}/3/${MEDIA_TYPE}/$ITEM_ID/rating?api_key=${V3_API_KEY}&session_id=${V3_SESSION_ID}" \
      --data '{"value":'${RATE}'}' \
    | jq '. | .success'

    echo "${i}/${N_ITEMS}"
    i=$((i + 1))
    sleep 1
  done
}



################################################################################
# $1 - Number of items that will be imported (just to count)
# $2 - Type
# $@ - IMDB ids to be imported
################################################################################
import_watch_list() {
  N_ITEMS=$1
  TYPE=$2
  shift
  shift

  ACCOUNT_ID=$(find_account_id)
  echo "---"
  echo "$ACCOUNT_ID"
  echo "---"

  i=1
  for imdb in $@; do
    ITEM_ID=$(find_id_by_imdb $imdb $TYPE)
    MEDIA_TYPE=$(type_to_s $TYPE)

    curl --silent \
      --header "Content-Type: application/json" \
      --request POST "${BASE_PATH}/3/account/${ACCOUNT_ID}/watchlist?api_key=${V3_API_KEY}&session_id=${V3_SESSION_ID}" \
      --data '{"media_type":"'${MEDIA_TYPE}'", "media_id":"'${ITEM_ID}'", "watchlist": true}' \
    | jq '. | .success'

    echo "${i}/${N_ITEMS}"
    i=$((i + 1))
    sleep 1
  done
}



################################################################################
# $1 - Filename
# $2 - Type
# $3 - Status
################################################################################
filter_ids() {
  cat $1 | \
    jq -r "
      .[]
      | select(.type==$2)
      | select(.status | contains(\"$3\"))
      | select(.imdb!=null)
      | .imdb"
}



################################################################################
# $1 - Filename
# $2 - Type
# $3 - Status
################################################################################
count_ids() {
  cat $1 | \
    jq "
      [.[]
      | select(.type==$2)
      | select(.status | contains(\"$3\"))
      | select(.imdb!=null)]
      | length"
}



################################################################################
# $1 - Filename
# $2 - Type
# $3 - Status
################################################################################
filter_rates() {
  cat $1 | \
    jq "
      .[]
      | select(.type==$2)
      | select(.rating!=null)
      | {imdb: .imdb, rating: .rating}"
}



################################################################################
# $1 - Filename
# $2 - Type
################################################################################
count_rates() {
  cat $1 | \
    jq "
      [.[]
      | select(.type==$2)
      | select(.rating!=null)]
      | length"
}



################################################################################
# $1 - Filename
# $2 - List name
# $3 - Type
#   TV_SHOWS=1
#   MOVIES=2
#   DOCUMENTARY=3
# $4 - Status
#
lists_importer() {
  echo ""
  echo "Creating $2 list..."
  LIST_ID=$(create_list $2)
  echo "List $2 created with id: ${LIST_ID}"

  IMDB_IDS=$(filter_ids $1 $3 $4)
  N_IDS=$(count_ids $1 $3 $4)

  echo ""
  echo "Importing ${N_IDS} WATCHED to $2..."

  import_to_list ${N_IDS} $3 ${LIST_ID} ${IMDB_IDS}
}



################################################################################
# $1 - Filename
# $2 - Type
#   TV_SHOWS=1
#   MOVIES=2
#   DOCUMENTARY=3
#
rates_importer() {
  RATES_DATA=$(filter_rates $1 $2)
  N_IDS=$(count_rates $1 $2)
  echo ""
  echo "Importing ${N_IDS} rates..."

  import_rates ${N_IDS} $2 ${RATES_DATA}
}



################################################################################
# $1 - Filename
# $2 - Type
#   TV_SHOWS=1
#   MOVIES=2
#   DOCUMENTARY=3
#
watch_list_importer() {
  IMDB_IDS=$(filter_ids $1 $2 "pending")
  N_IDS=$(count_ids $1 $2 "pending")
  echo ""
  echo "Importing ${N_IDS} PENDING..."

  import_watch_list ${N_IDS} $2 ${IMDB_IDS}
}



################################################################################
# Main
main() {
  # Default values
  FILENAME="tviso-collection.json"

  WATCHED_MOVIES_LIST_NAME="Watched_Movies"
  WATCHED_TV_SHOWS_LIST_NAME="Watched_Series"
  WATCHED_DOCUMENTARY_LIST_NAME="Watched_Documentaries"
  FOLLOWING_TV_SHOWS_LIST_NAME="Following_Series"


  # Types
  TV_SHOWS=1
  MOVIES=2
  DOCUMENTARY=3


  while getopts 'f:h' OPTION; do
    case "$OPTION" in
      f)
        FILENAME=$OPTARG
        ;;
      h)
        help
        exit 1
        ;;
      ?)
        help
        exit 1
        ;;
    esac
  done
  shift "$(($OPTIND -1))"


  echo ""
  echo "File: $FILENAME"


  local choice
  read -p "
What do you want to import?
  0) Import everything
  1) Watched movies
  2) Watched tv shows
  3) Watched documentaries
  4) Rated movies
  5) Rated tv shows
  6) Rated documentaries
  7) Pending movies
  8) Pending tv shows
  9) Pending documentaries
  10) Following tv shows
  " choice
  case $choice in
    0)
      echo ""
      echo "Importing everything..."

      lists_importer ${FILENAME} ${WATCHED_MOVIES_LIST_NAME} ${MOVIES} "watched"
      lists_importer ${FILENAME} ${WATCHED_TV_SHOWS_LIST_NAME} ${TV_SHOWS} "watched"
      lists_importer ${FILENAME} ${WATCHED_DOCUMENTARY_LIST_NAME} ${DOCUMENTARY} "watched"
      rates_importer ${FILENAME} ${MOVIES}
      rates_importer ${FILENAME} ${TV_SHOWS}
      rates_importer ${FILENAME} ${DOCUMENTARY}
      watch_list_importer ${FILENAME} ${MOVIES}
      watch_list_importer ${FILENAME} ${TV_SHOWS}
      watch_list_importer ${FILENAME} ${DOCUMENTARY}
      lists_importer ${FILENAME} ${FOLLOWING_TV_SHOWS_LIST_NAME} ${TV_SHOWS} "following"

      echo "Done"
      exit 0
      ;;
    1)
      echo ""
      echo "Importing watched movies..."
      lists_importer ${FILENAME} ${WATCHED_MOVIES_LIST_NAME} ${MOVIES} "watched"
      echo "Done"
      exit 0
      ;;
    2)
      echo ""
      echo "Importing watched tv shows..."
      lists_importer ${FILENAME} ${WATCHED_TV_SHOWS_LIST_NAME} ${TV_SHOWS} "watched"
      echo "Done"
      exit 0
      ;;
    3)
      echo ""
      echo "Importing wathed documentaries..."
      lists_importer ${FILENAME} ${WATCHED_DOCUMENTARY_LIST_NAME} ${DOCUMENTARY} "watched"
      echo "Done"
      exit 0
      ;;
    4)
      echo ""
      echo "Importing rated movies..."
      rates_importer ${FILENAME} ${MOVIES}
      echo "Done"
      ;;
    5)
      echo ""
      echo "Importing rated tv shows..."
      rates_importer ${FILENAME} ${TV_SHOWS}
      echo "Done"
      exit 0
      ;;
    6)
      echo ""
      echo "Importing rated documentaries..."
      rates_importer ${FILENAME} ${DOCUMENTARY}
      echo "Done"
      exit 0
      ;;
    7)
      echo ""
      echo "Importing pending movies..."
      watch_list_importer ${FILENAME} ${MOVIES}
      echo "Done"
      ;;
    8)
      echo ""
      echo "Importing pending tv shows..."
      watch_list_importer ${FILENAME} ${TV_SHOWS}
      echo "Done"
      exit 0
      ;;
    9)
      echo ""
      echo "Importing pending documentaries..."
      watch_list_importer ${FILENAME} ${DOCUMENTARY}
      echo "Done"
      exit 0
      ;;
    10)
      echo ""
      echo "Importing following tv shows..."
      lists_importer ${FILENAME} ${FOLLOWING_TV_SHOWS_LIST_NAME} ${TV_SHOWS} "following"
      echo "Done"
      exit 0
      ;;
    *)
      echo "Error"
      exit 1
      ;;
  esac
}

main "$@"

