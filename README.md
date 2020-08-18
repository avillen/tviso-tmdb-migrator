## Instructions

1. Download the tviso `.json` backup from: `https://es.tviso.com/my-settings/export-collection`
2. Copy the `tviso-collection.json` file inside this directory.
3. Go to `https://www.themoviedb.org/settings/api` and create an app.
4. Create a `.secrets` file and copy the v3 API key in the first line and the v4 API key in the second line.
5. Run `chmod +x import.sh`.
6. Run `./import.sh` (run `./import.sh -h` for more options).
