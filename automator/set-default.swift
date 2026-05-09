import Foundation
import CoreServices

let bundleID = "com.mdpreview.app"
let utis = ["net.daringfireball.markdown"]

var allOK = true
for uti in utis {
    let status = LSSetDefaultRoleHandlerForContentType(
        uti as CFString,
        LSRolesMask.viewer,
        bundleID as CFString
    )
    if status != noErr {
        fputs("warning: could not register \(uti): OSStatus \(status)\n", stderr)
        allOK = false
    }
}

if allOK {
    print("✓ MDPreview set as default Markdown opener")
}
exit(allOK ? 0 : 1)
