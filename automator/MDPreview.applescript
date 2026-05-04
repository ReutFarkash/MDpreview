-- MDPreview.app — drop .md files on this app or set it as default opener.
-- md-preview.sh is bundled inside Contents/Resources/ — no path injection needed.
on open theFiles
	set appPath to POSIX path of (path to me)
	set scriptPath to appPath & "Contents/Resources/md-preview.sh"
	repeat with theFile in theFiles
		set filePath to POSIX path of theFile
		do shell script "bash " & quoted form of scriptPath & " " & quoted form of filePath
	end repeat
end open

-- Allow launching without a file: auto-setup on first run, then open the vault.
on run
	set appPath to POSIX path of (path to me)
	set setupPath to appPath & "Contents/Resources/setup.sh"
	do shell script "[ -d \"$HOME/MDPreview\" ] || bash " & quoted form of setupPath
	do shell script "open 'obsidian://open?vault=MDPreview'"
end run
