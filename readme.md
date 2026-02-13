# Xournal GradeExam plugin

This [xournal](https://xournalpp.github.io) plugin aims to help teachers to quickly correct and export student work of any kind (exams, homeworks…). Are are the most important features:
- You can correct "free-form" exams, i.e. you don't need to ask students to write their answers in a fixed position.
- We provide tools to join multiple PDF into a single one and to "cut" scans of double page A4 = A3 documents into single-page A4 documents since this plugin expects to start with a single PDF containing all documents to grade. Scanning all exams can be done really quickly, notably using the fact that most professional printers can scan piles of A3 documents in a few seconds, otherwise you can still use a (e.g. guillotine) paper cutter to turn double page documents into single page, or take photos of the double page exam (maybe longer).
- You can either grade in points or in percentage.
- We allow easy export of the grade in a CSV that you can import in Excel/Libre office. You can specify for each question the maximum score used for instance when grading in percentage.
- Grades can be exported in a pre-defined order based on an existing list of student, e.g. copy/pasted from an existing reference Excel file.
- We provide tools to quickly identify the beginning of each exam and assign it to the corresponding student, for instance using a reference list of students.
- We provide shortcuts to quickly move to the next question to grade, either by going to the last graded question (most of the time the next question will be located right after), or if you pre-created questions with empty score where students wrote their answers, it will move to the smallest question that has no score.
- It is a xournal plugin, meaning that you can annotate PDF with the very reach-feature xournal PDF editor as usual, including with graphic tablets.
- Deal with homeworks done in team of multiple students

## Installation

- First, **install a really recent version of Xournal** to include [this PR merged on 2026/02/6](https://github.com/xournalpp/xournalpp/pull/7035) or export will be extremely slow and you may lack some features. We do our best to support older versions of Xournal lacking the needed API, but it is extremely slow notably when exporting since we need to navigate all the document, and we also can't support all wanted features for instance to skip students whose current question has already been corrected.
- Then, download the files in this repo (technically only `plugin.ini` and `main.lua` are needed), e.g. by downloading [the zip archive](https://github.com/leo-colisson/xournalGradeExam/archive/refs/heads/main.zip) and decompressing them at the root of the folder `/home/<user>/.config/xournalpp/plugins/gradeExam/` on Linux (so at the end you should have the files `/home/<user>/.config/xournalpp/plugins/gradeExam/{plugin.ini,main.lua}`, make sure to create the folders as they won't exist by default), `/Users/<user>/.config/xournalpp/gradeExam/` on MacOS, and `C:\Users\<user>\AppData\Local\xournalpp\gradeExam\` on Windows.
- To use the features to join PDF and decompose double pages scanned PDF into single pages, you should [install `python`](https://www.python.org/downloads/) and the `pypdf` dependency, e.g. by typing `python3 -m pip install pypdf` in a terminal (if you are on windows first start the `cmd` or `powershell` program to type commands).
- To use the features to quickly assign a student to its exam, you need to install `rofi` on Linux, [`wlines.exe` on windows](https://github.com/JerwuQu/wlines) (not tested, please give me returns), and [`choose` on MacOS](https://github.com/chipsenkbeil/choose). To install `wlines.exe` on windows, you can copy the downloaded file to an arbitrary folder, and change the `PATH` environment variable as [described here](https://learn.microsoft.com/en-us/previous-versions/office/developer/sharepoint-2010/ee537574(v=office.14)) to add this folder so that our plugin knows where to find it. **If you are too lazy to install these dependencies**, you can also simply manually type the name of the student (use TAB or `|` to separate student ID, first name, last name…) and we will do our best to match it with the reference list when exporting.

## Usage

TODO: in the meantime, play with the "Plugin" menu where we added some items.

## TODOs and known issues

This plugin is already fairly usable but still under development: it has notably been poorly tested (especially on Windows & MacOS), so please report in the [Github issue tracker](https://github.com/leo-colisson/xournalGradeExam/issues) any bug you may encounter. We also have a list of remaining TODO to implement, if you are interested in one feature (listed here or not), feel free to drop a message in the above bug report to motivate me to code it quickly:
- Go backward
- Allow template to pre-position the elements
- Allow to specify that all remaining grades should be set to 0, or introduce `*end:`
- Automatically add the next grade when clicking or drawing in the margin. First, we need to implement in Xournal++ a way too add hooks to detect clicks, see [this discussion](https://github.com/xournalpp/xournalpp/discussions/7067). 
- Better documentation & vidéos
- The menu is a bit cluttered with many not-so-useful entries. Try to hide them in a submenu [if we find a way to do that with Xournal++](https://github.com/xournalpp/xournalpp/discussions/7119).
- Export without background to allow teacher to print comments over written exams (not sure how reliable this would be)
- Provide methods to automatically send emails with exams to each student, or to synchronize it automatically with Moodle, or to encrypt with a password so that all exams can be put on an arbitrary server.

## Related tools

- PDF4Teachers
- [CorrectExam](https://correctexam.github.io/)
