-- Receives the files macOS opens with this app and hands them to
-- open-in-rex.sh, which build.sh copies into the app's Resources.
on open theFiles
	set script_path to POSIX path of (path to resource "open-in-rex.sh")
	set args to ""
	repeat with f in theFiles
		set args to args & " " & quoted form of POSIX path of f
	end repeat
	do shell script quoted form of script_path & args
end open

-- Launched with no files (from Finder or Spotlight): nothing to open.
on run
end run
