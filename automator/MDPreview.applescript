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
	set setDefaultPath to appPath & "Contents/Resources/set-default"

	-- Detect first run before setup creates the vault
	set vaultExists to (do shell script "[ -d \"$HOME/MDPreview\" ] && echo yes || echo no")

	if vaultExists is "no" then
		do shell script "bash " & quoted form of setupPath & " --theme bundled"

		-- Dialog works natively here; do shell script subprocesses can't show UI
		set choice to button returned of (display dialog "Would you like MDPreview to open .md files by default?" buttons {"Not Now", "Set as Default"} default button "Set as Default" with title "MDPreview")
		if choice is "Set as Default" then
			do shell script quoted form of setDefaultPath
		end if
	end if

	do shell script "open 'obsidian://open?vault=MDPreview'"
end run
