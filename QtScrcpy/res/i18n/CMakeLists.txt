# Translation source files
set(QC_TS_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/en_US.ts
    ${CMAKE_CURRENT_SOURCE_DIR}/ja_JP.ts
    ${CMAKE_CURRENT_SOURCE_DIR}/ru_RU.ts
)
# Output directory for qm files
set_source_files_properties(${QC_TS_FILES} PROPERTIES OUTPUT_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}")
# Import LinguistTools
find_package(QT NAMES Qt6 Qt5 COMPONENTS LinguistTools REQUIRED)
find_package(Qt${QT_VERSION_MAJOR} COMPONENTS LinguistTools REQUIRED)

# qt5_create_translation runs lupdate (update ts) then lrelease (generate qm)
qt5_create_translation(QM_FILES ${CMAKE_CURRENT_SOURCE_DIR}/../.. ${QC_TS_FILES})
# Custom target depends on QM_FILES, otherwise qm files won't be generated
add_custom_target(QC_QM_GENERATOR DEPENDS ${QM_FILES})

# qt5_create_translation bug: cmake clean deletes translated ts files, losing translations
# (Qt officially says qt6 doesn't have this issue)
# CLEAN_NO_CUSTOM only works with Makefile generators, doesn't solve the problem
# https://cmake.org/cmake/help/latest/prop_dir/CLEAN_NO_CUSTOM.html
# set_directory_properties(PROPERTIES CLEAN_NO_CUSTOM true)
# Current workaround: after each clean, manually restore ts files from git

#[[
Summary:
Three ways to handle translations in a cmake Qt project:
1. Use Qt's built-in cmake LinguistTools: qt5_create_translation & qt5_add_translation
   - qt5_add_translation can only generate qm from existing ts (lrelease), cannot update ts (lupdate)
   - qt5_create_translation deletes translated ts files on cmake clean

2. cmake add_custom_command + LinguistTools
   e.g. add_custom_command for lupdate, combined with qt5_add_translation for qm
   Reference: https://github.com/maratnek/QtFirstProgrammCMake/blob/2c93b59e2ba85ff6ee0e727487e14003381687d3/CMakeLists.txt

3. Use cmake commands directly for lupdate and lrelease
   e.g. add_custom_command/add_custom_target/execute_process

All 3 approaches share a common issue: translation processing is tied to compilation.
In practice, translation should be done once after all code is complete, not on every build.
Using shell scripts (lupdate.sh / lrelease.sh) is more appropriate:
1. Update ts: lupdate -no-obsolete ./QtScrcpy -ts ./QtScrcpy/res/i18n/en_US.ts ./QtScrcpy/res/i18n/ru_RU.ts
2. Translate ts manually
3. Release: lrelease ./QtScrcpy/res/i18n/en_US.ts ./QtScrcpy/res/i18n/ru_RU.ts

References:
1. Qt knows about qt5_create_translation bug, confirmed fixed in qt6: https://bugreports.qt.io/browse/QTBUG-96549
2. https://doc.qt.io/qt-5/qtlinguist-cmake-qt5-add-translation.html
3. https://doc.qt.io/qt-5/qtlinguist-cmake-qt5-create-translation.html
