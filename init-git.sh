# Tell Git to take the existing file whenever merging files with the "ours" driver.
# This is used for things like SR2MM's branch description files, since those are specific to each branch.
git config merge.ours.driver true

# Note to self: A hypothetical 'theirs' merge driver would require me to define a shell script with the following code:
## cp -f "$3" "$2"
## exit 0
# Per https://stackoverflow.com/a/930495, this driver would be registered via as `${filename} %O %A %B` (using JS string interpolation syntax for readability), and would have to be added to the user's PATH. The details vary depending on the user's OS.