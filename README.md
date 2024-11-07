# auto_video_fixer_cli_linux
repair corrupt videos with this


To check which files have already been processed and recorded in your SQLite database, you can run a simple SQL query against the `checked_files` table. This will allow you to retrieve the list of files that have been inserted into the database.

Here's how you can do it using the `sqlite3` command-line tool:

1. Open your terminal.

2. Run the following command, replacing `checked_files.db` with the path to your SQLite database file if it is not in the current directory:

`markdown
bash
   sqlite3 checked_files.db "SELECT filepath FROM checked_files;"
``` 


This command will display all file paths that have been recorded in the `checked_files` table, meaning these are the files that have already been processed by your script.

If you want to save the output to a file instead of displaying it on the terminal, you can redirect the output like this:

bash
sqlite3 checked_files.db "SELECT filepath FROM checked_files;" > checked_files_list.txt


This will create a file named `checked_files_list.txt` containing the paths of all files that have already been checked. This can be useful for further analysis or record-keeping.
