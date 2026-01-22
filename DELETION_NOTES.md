//
//  TFTheme+Notes.swift
//  
//
//  Created by User on 2026-01-21.
//

/*
 Notes on Recent Refactoring:

 - The following files were removed as they were unused in the project:
    • TFCardStyle.swift
    • TFBackground.swift
    • TFChalkboardBackground.swift
    • TFBackgroundView.swift

 - The 'tfTexturedCard' component has been fully replaced by 'tfDynamicCard'.

 - Backgrounds have been standardized and are now handled via
   `TFTheme.tfBackground()` which utilizes `DynamicChalkboardBackground()`.

 This cleanup helps maintain a more streamlined and maintainable codebase.
*/
