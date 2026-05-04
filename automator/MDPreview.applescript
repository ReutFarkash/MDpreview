-- MDPreview.app — drop .md files on this app or set it as default opener.
-- MDPREVIEW_SH_PATH is replaced by install.sh with the actual path to md-preview.sh
on open theFiles
	repeat with theFile in theFiles
		set filePath to POSIX path of theFile
		do shell script "MDPREVIEW_SH_PATH " & quoted form of filePath
	end repeat
end open

-- Allow launching without a file (opens Obsidian vault directly)
on run
	do shell script "open 'obsidian://open?vault=MDPreview'"
end run
