#!/bin/sh
# vim: ai:ts=8:sw=8:noet


TMDB_API_TOKEN=$(head -n 1 .secrets)


################################################################################
#
################################################################################
help() {
  echo " -f <Name of the .json file>"
}



################################################################################
# $1 - List name
################################################################################
create_list() {
  # sleep 0.7

  echo "id_of_the_created_list"
}



################################################################################
# $1 - Number of items that will be imported (just to count)
# $2 - ID of the list where the item will be added
# $@ - IMDB ids to be imported
################################################################################
import_to_list() {
  N_ITEMS=$1
  ID_LIST=$2
  shift
  shift

  i=1
  for k in $@; do
    echo "${i}/${N_ITEMS}"
    i=$((i + 1))
    # sleep 0.7
  done
}



################################################################################
# $1 - Number of items that will be imported (just to count)
# $@ - Rates json with id and rate to be imported
################################################################################
import_rates() {
  i=1

  N_ITEMS=$1
  shift

  echo "$@" | jq -c '.' | while IFS= read -r line; do
    IMDB=$(echo $line | jq -j '.imdb')
    RATE=$(echo $line | jq -j '.rating')

    echo "${i}/${N_ITEMS}"
    i=$((i + 1))
    # sleep 0.7
  done
}



################################################################################
# $1 - Number of items that will be imported (just to count)
# $@ - IMDB ids to be imported
################################################################################
import_watch_list() {
  N_ITEMS=$1
  shift

  i=1
  for k in $@; do
    echo "${i}/${N_ITEMS}"
    i=$((i + 1))
    # sleep 0.7
  done
}



################################################################################
# $1 - Filename
# $2 - Type
# $3 - Status
################################################################################
filter_ids() {
  cat $1 | \
    jq "
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
# $1 - List name
# $2 - Filename
# $3 - Type
#   TV_SHOWS=1
#   MOVIES=2
#   DOCUMENTARY=3
#
lists_importer() {
  echo ""
  echo "Creating $1 list..."
  LIST_ID=$(create_list $1)
  echo "List $1 created"

  IMDB_IDS=$(filter_ids $2 $3 "watched")
  N_IDS=$(count_ids $2 $3 "watched")

  echo ""
  echo "Importing ${N_IDS} WATCHED to $1..."

  import_to_list ${N_IDS} ${LIST_ID} ${IMDB_IDS}
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

  import_rates ${N_IDS} ${RATES_DATA}
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

  import_watch_list ${N_IDS} ${IMDB_IDS}
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
    1)
      echo ""
      echo "Importing watched movies..."
      lists_importer ${WATCHED_MOVIES_LIST_NAME} ${FILENAME} ${MOVIES}
      echo "Done"
      exit 0
      ;;
    2)
      echo ""
      echo "Importing watched tv shows..."
      lists_importer ${WATCHED_TV_SHOWS_LIST_NAME} ${FILENAME} ${TV_SHOWS}
      echo "Done"
      exit 0
      ;;
    3)
      echo ""
      echo "Importing wathed documentaries..."
      lists_importer ${WATCHED_DOCUMENTARY_LIST_NAME} ${FILENAME} ${DOCUMENTARY}
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
      lists_importer ${FOLLOWING_TV_SHOWS_LIST_NAME} ${FILENAME} ${TV_SHOWS}
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

