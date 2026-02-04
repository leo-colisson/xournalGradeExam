-- See discussion in https://github.com/xournalpp/xournalpp/issues/7007

-- TODO:
-- - Allow multiple users same exam
-- - Go backward
-- - Allow questions in random order and pre-filled positions
-- - Allow template to pre-position the elements
-- - Allow to specify that all remaining grades should be set to 0

local PREFIX_NAME = "*:"
local PREFIX_REF_STUDENTS = "*students:"
local SEP_NAME = "__" -- TODO: rather use | and TAB (allow both)
local GRADE_SEP = "=>"
local CSV_SEP = "\t"
local FOLDER_EXPORT = "pdf_exports"
   
-- Settings car be configured via a text like:
-- *settings:
-- optionA = foo
-- optionB = bar
--
-- The list of options is:
-- - removeNoGradeCells = false/true (default true)
local PREFIX_SETTING = "*settings:"

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. ''..k..' = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function get_file_name(file)
      return file:match("[^/\\]*$")
end


function isUnix()
   return package.config:sub(1,1) == '/'
end

function getOS()
   if package.config:sub(1,1) ~= '/' then
      return "windows"
   else
      -- Unix, Linux variants
      local fh, err = assert(io.popen("uname 2>/dev/null", "r"))
      if fh then
         local osname = trim(fh:read():lower())
         if osname == "linux" then
            return "linux"
         elseif osname == "darwin" then
            return "darwin"
         else
            print("WARNING: unknown OS " .. osname .. ", defaulting to linux.")
            return "linux"
         end
      end
   end
end


function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end


function trim(x)
   return x:match("^%s*(.-)%s*$")
end

function split(s, delimiter)
    result = {};
    delimiter_regexp = delimiter:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
    for match in (s..delimiter):gmatch("(.-)"..delimiter_regexp) do
        table.insert(result, match);
    end
    return result;
end


-- We allow SEP_NAME and TAB to separate names
-- We don't have "OR" in pattern matching
-- https://stackoverflow.com/questions/3462370/logical-or-in-lua-patterns
-- https://www.lua.org/manual/5.5/manual.html#6.5.1
-- so to do "SEP_NAME or TAB", we first cut on SEP_NAME, then TAB, and we also strip
-- white space
function split_student_name_in_columns(student)
   local res = {}
   for _,x in ipairs(split(student, SEP_NAME)) do
      for _,y in ipairs(split(x, "\t")) do
         table.insert(res, trim(y))
      end
   end
   return res
end


local function int_to_spreadsheet_col(n)
    local s = ""
    while n > 0 do
        n = n - 1
        s = string.char(65 + (n % 26)) .. s
        n = math.floor(n / 26)
    end
    return s
end

-- https://stackoverflow.com/questions/19326368/iterate-over-lines-including-blank-lines
function iterate_on_lines(s)
        if s:sub(-1)~="\n" then s=s.."\n" end
        return s:gmatch("(.-)\n")
end

-- https://stackoverflow.com/questions/50459102/replace-accented-characters-in-string-to-standard-with-lua
function normalizeLatin(str)
  local tableAccents = {}
    tableAccents["À"] = "A"
    tableAccents["Á"] = "A"
    tableAccents["Â"] = "A"
    tableAccents["Ã"] = "A"
    tableAccents["Ä"] = "A"
    tableAccents["Å"] = "A"
    tableAccents["Æ"] = "AE"
    tableAccents["Ç"] = "C"
    tableAccents["È"] = "E"
    tableAccents["É"] = "E"
    tableAccents["Ê"] = "E"
    tableAccents["Ë"] = "E"
    tableAccents["Ì"] = "I"
    tableAccents["Í"] = "I"
    tableAccents["Î"] = "I"
    tableAccents["Ï"] = "I"
    tableAccents["Ð"] = "D"
    tableAccents["Ñ"] = "N"
    tableAccents["Ò"] = "O"
    tableAccents["Ó"] = "O"
    tableAccents["Ô"] = "O"
    tableAccents["Õ"] = "O"
    tableAccents["Ö"] = "O"
    tableAccents["Ø"] = "O"
    tableAccents["Ù"] = "U"
    tableAccents["Ú"] = "U"
    tableAccents["Û"] = "U"
    tableAccents["Ü"] = "U"
    tableAccents["Ý"] = "Y"
    tableAccents["Þ"] = "P"
    tableAccents["ß"] = "s"
    tableAccents["à"] = "a"
    tableAccents["á"] = "a"
    tableAccents["â"] = "a"
    tableAccents["ã"] = "a"
    tableAccents["ä"] = "a"
    tableAccents["å"] = "a"
    tableAccents["æ"] = "ae"
    tableAccents["ç"] = "c"
    tableAccents["è"] = "e"
    tableAccents["é"] = "e"
    tableAccents["ê"] = "e"
    tableAccents["ë"] = "e"
    tableAccents["ì"] = "i"
    tableAccents["í"] = "i"
    tableAccents["î"] = "i"
    tableAccents["ï"] = "i"
    tableAccents["ð"] = "eth"
    tableAccents["ñ"] = "n"
    tableAccents["ò"] = "o"
    tableAccents["ó"] = "o"
    tableAccents["ô"] = "o"
    tableAccents["õ"] = "o"
    tableAccents["ö"] = "o"
    tableAccents["ø"] = "o"
    tableAccents["ù"] = "u"
    tableAccents["ú"] = "u"
    tableAccents["û"] = "u"
    tableAccents["ü"] = "u"
    tableAccents["ý"] = "y"
    tableAccents["þ"] = "p"
    tableAccents["ÿ"] = "y"

  local normalisedString = ''

  local normalisedString = str: gsub("[%z\1-\127\194-\244][\128-\191]*", tableAccents)

  return normalisedString

end

-- Register all Toolbar actions and intialize all UI stuff
function initUi()
  app.registerUi({["menu"] = "GradeExam: last grade next student + save", ["callback"] = "gotoLastGradeNextStudentAndSave", ["accelerator"] = "F4"});
  app.registerUi({["menu"] = "GradeExam: last grade next student", ["callback"] = "gotoLastGradeNextStudent"});
  app.registerUi({["menu"] = "GradeExam: next student", ["callback"] = "gotoNextStudent"});
  app.registerUi({["menu"] = "GradeExam: last grade", ["callback"] = "gotoLastGrade"});
  app.registerUi({["menu"] = "GradeExam: CSV", ["callback"] = "generateCSV", mode = 1});
  app.registerUi({["menu"] = "GradeExam: CSV (percent formula)", ["callback"] = "generateCSV", mode = 2});
  app.registerUi({["menu"] = "GradeExam: export pdf", ["callback"] = "exportPdf"});
  app.registerUi({["menu"] = "GradeExam: debug", ["callback"] = "debug"});
  app.registerUi({["menu"] = "GradeExam: add student", ["callback"] = "createStudent", ["accelerator"] = "F2"});
  -- F1 will be used to go backward, F3 will be used to add grades
end

function sortTexts(a,b)
   if a.page == b.page then
      -- We write students first, simpler to deal with later
      local a_is_student = string.sub(a.text,1,#PREFIX_NAME) == PREFIX_NAME
      local b_is_student = string.sub(b.text,1,#PREFIX_NAME) == PREFIX_NAME
      if a_is_student and b_is_student then
         return a.y < b.y
      elseif a_is_student then
         return true
      elseif b_is_student then
         return false
      else
         return a.y < b.y
      end
   else
      return a.page < b.page
   end
end

function getAllTexts()
   -- This function only exists in a pull request of mine for now, if it does not exist
   -- we fallback to a dirty loop and print a warning
   local status, err_or_res = pcall(function () return app.getTexts("all") end)
   if status then
      -- If multiple grades are on the same page, make sure to read them from top to bottom
      table.sort(err_or_res, sortTexts)
      return err_or_res
   else
      local msg = "WARNING: we are falling back to a really inefficient solution because your installed xournalpp is too old. You should upgrade or be ready to wait maybe 30s on large documents."
      print(msg)
      app.openDialog(msg, {"Continue"}, nil) -- This is not blocking, use callbacks otherwise
      local texts = {}
      local index = 1
      local docStructure = app.getDocumentStructure()
      local numPages = #docStructure.pages
      for i=1, numPages do
         app.setCurrentPage(i)
         local numLayers = #docStructure.pages[i].layers
         for j=1, numLayers do
            app.setCurrentLayer(j)
            local textsOnLayer = app.getTexts("layer")
            for k=1, #textsOnLayer do
               textsOnLayer[k].page = i
               textsOnLayer[k].layer = j
               table.insert(texts, textsOnLayer[k])
               index = index + 1
            end
         end
      end
      -- If multiple grades are on the same page, make sure to read them from top to bottom
      table.sort(texts, function(a, b)
                    if a.page == b.page then
                       return a.y < b.y
                    else
                       return a.page < b.page
                    end
      end)
      return texts
   end
end

function extractTextsInPreamble(allTexts)
   local res = {}
   for _,currText in ipairs(allTexts) do
      -- Try to check if new student (=starts with PREFIX_NAME)
      if string.sub(currText.text,1,#PREFIX_NAME) == PREFIX_NAME then
         break
      else
         table.insert(res, currText)
      end
   end
   return res
end 

-- Like extractTextsInPreamble(getAllTexts()) to only gets stuff in preamble, but does it significantly more efficiently in old xournal since it stops after the preamble
function getAllTextsInPreamble()
   -- This function only exists in a pull request of mine for now, if it does not exist
   -- we fallback to a dirty loop and print a warning
   local status, err_or_res = pcall(function () return app.getTexts("all") end)
   if status then
      return extractTextsInPreamble(err_or_res)
   else
      local res = {}
      local resCurrentPage = {} -- Maybe names appear after a grade... unlikely but who knows
      local currentPage = 1
      local msg = "WARNING: we are falling back to a really inefficient solution because your installed xournalpp is too old. You should upgrade or be ready to wait maybe 30s on large documents."
      print(msg)
      app.openDialog(msg, {"Continue"}, nil) -- This is not blocking, use callbacks otherwise
      local index = 1
      local docStructure = app.getDocumentStructure()
      local numPages = #docStructure.pages
      for i=1, numPages do
         app.setCurrentPage(i)
         local numLayers = #docStructure.pages[i].layers
         for j=1, numLayers do
            app.setCurrentLayer(j)
            local textsOnLayer = app.getTexts("layer")
            for k=1, #textsOnLayer do
               textsOnLayer[k].page = i
               textsOnLayer[k].layer = j
               index = index + 1
               -- Try to check if new student (=starts with PREFIX_NAME)
               if string.sub(textsOnLayer[k].text,1,#PREFIX_NAME) == PREFIX_NAME then
                  return res
               elseif textsOnLayer[k].page == currentPage then
                  table.insert(resCurrentPage, textsOnLayer[k])
               else
                  -- we merge the current page back
                  for _,v in ipairs(resCurrentPage) do
                     table.insert(res, v)
                  end
                  resCurrentPage = { textsOnLayer[k] }
                  currentPage = textsOnLayer[k].page
               end
            end
         end
      end
      return texts
   end
end

-- Extracts a hash and a table of all reference students
function getReferenceStudents(allTextsInPreamble)
   print("getReferenceStudents", dump(allTextsInPreamble))
   local referenceStudentsHash = {}
   local referenceStudentsArray = {}
   for _, currText in ipairs(allTextsInPreamble) do
      -- Try to check if it is the list of all students (=starts with PREFIX_REF_STUDENTS)
      if string.sub(currText.text,1,#PREFIX_REF_STUDENTS) == PREFIX_REF_STUDENTS then
         for currLine in iterate_on_lines(currText.text) do
            if currLine ~= PREFIX_REF_STUDENTS then
               if referenceStudentsHash[currLine] == nil then
                  table.insert(referenceStudentsArray, currLine)
                  referenceStudentsHash[currLine] = true
               end
            end
         end
      end
   end
   return referenceStudentsHash, referenceStudentsArray
end

function isStudentName(text)
   if string.sub(text,1,#PREFIX_NAME) == PREFIX_NAME then
      return string.sub(text,#PREFIX_NAME+1,-1)
   else
      return nil
   end
end

-- findReferenceForStudent("quick typed name") returns the possibly corrected new name, a number n of matches (1 means the name has been updated) and a warning error
function findReferenceForStudent(tmpCurrentStudent, referenceStudentsHash)
   print("findReferenceForStudent")
   print(dump(tmpCurrentStudent), dump(referenceStudentsHash))
   local currentStudent = nil
   if referenceStudentsHash[tmpCurrentStudent] then
      return tmpCurrentStudent, 1, nil
   else
      -- We split the name and see if it the first or second etc column have
      -- exactly one match
      student_cols = split_student_name_in_columns(tmpCurrentStudent)
      local msg = nil
      local nb_matches = 0
      for _,c in ipairs(student_cols) do
         local matches = {}
         local best_match_for_col = nil
         for student,_ in pairs(referenceStudentsHash) do
            if string.find(normalizeLatin(student):lower(), normalizeLatin(c):lower()) then
               table.insert(matches, student)
               best_match_for_col = student
            end
         end
         if #matches == 1 then
            currentStudent = best_match_for_col
            nb_matches = 1
            break
         elseif #matches > 1 then
            msg = "WARNING: found multiple matches for student " .. tmpCurrentStudent .. " (" .. c .. "):"
            nb_matches = #matches
            for _,name in ipairs(matches) do
               msg = msg .. "\n- " .. name
            end
         end
      end
      -- We found no good match
      if currentStudent == nil then
         currentStudent = tmpCurrentStudent
         if msg then
            return currentStudent, #matches, msg
         else
            return currentStudent, #matches, "WARNING: no matches found for the student " .. tmpCurrentStudent .. " in the reference list of students."
         end
      end
      return currentStudent, 1, nil
   end
end

-- Goto the next student, and return -1 if no student is found and the page otherwise
function gotoNextStudent()
   -- We go to the last question
   -- First we find the next student
   -- Not really efficient but only solution so far
   -- https://github.com/xournalpp/xournalpp/issues/7007
   local docStructure = app.getDocumentStructure()
   local numPages = #docStructure.pages
   for i=docStructure.currentPage + 1, numPages do
      -- We change page and search for texts on current page
      app.setCurrentPage(i)
      local numLayers = #docStructure.pages[i].layers
      for j=1, numLayers do
         app.setCurrentLayer(j)
         local textsOnLayer = app.getTexts("layer")
         for k=1, #textsOnLayer do
            -- Check if text starts with PREFIX_NAME
            if string.sub(textsOnLayer[k].text,1,#PREFIX_NAME) == PREFIX_NAME then
               app.scrollToPage(i)
               return i
            end
         end
      end
   end
   return -1
end

function gotoLastGrade() 
   -- We go to the last grade
   local docStructure = app.getDocumentStructure()
   local numPages = #docStructure.pages
   local pageLastGrade = docStructure.currentPage
   local posLastGradeX = 0
   local posLastGradeY = 0
   for i=docStructure.currentPage, numPages do
      -- We change page and search for texts on current page
      app.setCurrentPage(i)
      local numLayers = #docStructure.pages[i].layers
      -- Check first if we are not on a new student
      if i ~= docStructure.currentPage then
         for j=1, numLayers do
            app.setCurrentLayer(j)
            local textsOnLayer = app.getTexts("layer")
            for k=1, #textsOnLayer do
               -- Check if text starts with PREFIX_NAME
               for k=1, #textsOnLayer do
                  -- Check if text starts with PREFIX_NAME
                  if string.sub(textsOnLayer[k].text,1,#PREFIX_NAME) == PREFIX_NAME then
                     -- We finished to loop over the current student
                     app.setCurrentPage(pageLastGrade)
                     app.scrollToPage(pageLastGrade)
                     app.scrollToPos(posLastGradeX, posLastGradeY)
                     return pageLastGrade
                  end
               end
            end
         end
      end
      -- Otherwise we check for new grades
      for j=1, numLayers do
         app.setCurrentLayer(j)
         local textsOnLayer = app.getTexts("layer")
         for k=1, #textsOnLayer do
            -- Grades look like "1.2 := 100"
            local res = string.find(textsOnLayer[k].text, "=>")
            if res ~= nil then
               pageLastGrade = i
               posLastGradeX = textsOnLayer[k].x
               posLastGradeY = textsOnLayer[k].y
            end
         end
      end
   end
   app.setCurrentPage(pageLastGrade)
   app.scrollToPage(pageLastGrade)
   app.scrollToPos(posLastGradeX, posLastGradeY)
   return pageLastGrade
end

function gotoLastGradeNextStudent()
   gotoNextStudent()
   gotoLastGrade(file)
end

-- Callback if the menu item is executed
function gotoLastGradeNextStudentAndSave()
   -- Not sure why, but print does not work with latest version (appimage), so let's
   -- debug by writting in a file
   -- file = io.open("debug.txt", "w")
   -- file:write("Hello world")
   app.activateAction("save")
   gotoLastGradeNextStudent()

   -- file:close()
end

-- mode = 1 is just copy/paste grades as it
-- mode = 2 is write a percent formula based on the max grade
function generateCSV(mode)
   local percent_formula = 2 -- alias for the mode 2, easier to read
   local warning_messages = {} -- Messages to display when finding unusual things
   -- We start to gather all texts
   local allTexts = getAllTexts()
   -- Stores the settings configured via PREFIX_SETTING
   local settings = {
      removeNoGradeCells = "false", -- If "true", the cells with "no grade" will actually be empty
   }
   -- Not sure why, but print does not work with latest version (appimage), so let's
   -- debug by writing in a file
   local docStructure = app.getDocumentStructure()
   local numPages = #docStructure.pages
   -- allGrades[student][grade] = value;
   local allGrades = {}
   -- If no student, it is the bareme, other grades may be expressible as a percentage of this value
   local bareme = "Max points"
   local currentStudent = bareme
   local tmpCurrentStudent = bareme
   local stillParsingBareme = true -- To know if we are already reading student stuff
   local baremeIsPresent = false -- To know if we are already reading student stuff
   -- We gather all questions by order of appearance
   local questionNamesHash = {} -- check efficiently if question already added
   -- show questions in the order they appear on the first copy (you may add an empty page first with all questions for a "bareme"
   -- that will be printed on the first line)
   local questionNamesArray = {}
   -- Same for students
   local studentHash = {}
   local studentArray = {}
   -- Optionally, if we add at the beginning of the document a list (or multiple lists)
   -- of students called like *students: followed by a new line and
   -- students, one per line, then we will try to write the grades in
   -- this order (if a student appears in the reference but has no
   -- grade, an empty line will be added with the reference
   -- name). When a match is found, the reference name is kept. To
   -- find matches, since it is easy to make a mistake in a name, we
   -- read the name of the student currently graded, if an entry
   -- exactly match its name we pick it otherwise we separate it based
   -- on SEP_NAME, try to match the first column, if there is not
   -- exactly one match we try with the second etc.
   local referenceStudentsHash = {} -- This is simply a map "reference student name" -> true
   local studentWithExam = {} -- To know if a student got no grade because they have no exam at all or because we forgot to grade it
   -- In mode percent_formula, we want a bareme
   if mode == percent_formula then
      allGrades[bareme] = {}
      studentHash[bareme] = 1 -- Use it like a set based on a hash table
      table.insert(studentArray,bareme)
   end
   local lastVisitedPage = 0
   local emptyPages = {} -- To print a warning if too many pages are empty (eg. forgot to correct one student because we forgot to write his name)
   -- We explore all pages of the document
   for _, currText in ipairs(allTexts) do
      -- Check if we forgot to annotate some pages
      if lastVisitedPage ~= currText.page then
         for i=lastVisitedPage+1,currText.page-1 do
            table.insert(emptyPages, i)
         end
         lastVisitedPage = currText.page
      end
      -- Try to check if it is the list of all students (=starts with PREFIX_REF_STUDENTS)
      if string.sub(currText.text,1,#PREFIX_REF_STUDENTS) == PREFIX_REF_STUDENTS then
         for currLine in iterate_on_lines(currText.text) do
            if currLine ~= PREFIX_REF_STUDENTS then
               referenceStudentsHash[currLine] = true
               allGrades[currLine] = allGrades[currLine] or {}
               if studentHash[currLine] == nil then
                  studentHash[currLine] = 1 -- Use it like a set based on a hash table
                  table.insert(studentArray,currLine)
               end
            end
         end
      end 
      -- Check if this is a setting (=starts with PREFIX_SETTING)
      if string.sub(currText.text,1,#PREFIX_SETTING) == PREFIX_SETTING then
         -- Allow multiple settings in the same box
         for line in iterate_on_lines(currText.text) do
            local res = string.find(line, "=")
            if res ~= nil then
               -- We trim white spaces
               local param = trim(string.sub(line, 1, res-1))
               local value = trim(string.sub(line, res + #GRADE_SEP, -1))
               settings[param] = value
            end
         end
      end
      -- Try to check if new student (=starts with PREFIX_NAME)
      if string.sub(currText.text,1,#PREFIX_NAME) == PREFIX_NAME then
         if stillParsingBareme and next(questionNamesArray) ~= nil then
            baremeIsPresent = true
         end
         stillParsingBareme = false
         -- We try to see if we find him in the list of reference students
         -- so we give him a temporary name until we know if it is in the list
         tmpCurrentStudent = string.sub(currText.text,#PREFIX_NAME+1,-1)
         local tmp_name, _, errors = findReferenceForStudent(tmpCurrentStudent, referenceStudentsHash)
         currentStudent = tmp_name
         if errors ~= nil then
            -- We print an error only if there is a reference list, otherwise meaningless
            if next(referenceStudentsHash) ~= nil then -- next(foo) == nil iff foo is empty
               table.insert(warning_messages, errors)
            end
         end
         studentWithExam[currentStudent] = true
         allGrades[currentStudent] = allGrades[currentStudent] or {}
         if studentHash[currentStudent] == nil then
            studentHash[currentStudent] = 1 -- Use it like a set based on a hash table
            table.insert(studentArray,currentStudent)
         end
      end
      -- Then we check for new grades (they look like "1.2 ~> 100" depending on separator)
      local res = string.find(currText.text, GRADE_SEP)
      if res ~= nil then
         -- We allow multiple grades separated by newlines
         for line in iterate_on_lines(currText.text) do
            local res = string.find(line, GRADE_SEP)
            if res ~= nil then
               -- We trim white spaces
               local question = trim(string.sub(line, 1, res-1))
               local points = trim(string.sub(line, res + #GRADE_SEP, -1))
               -- Create "Max points" if needed
               if allGrades[currentStudent] == nil then
                  allGrades[currentStudent] = {}
               end
               if allGrades[currentStudent][question] then
                  local msg = "WARNING: the student " .. currentStudent
                  if tmpCurrentStudent ~= currentStudent then
                     msg = msg .. " (aka " .. tmpCurrentStudent .. ")"
                  end
                  msg = msg .. " has question '" .. question .. "' specified twice.\n"
                  table.insert(warning_messages, msg)
               end
               allGrades[currentStudent][question] = points
               -- Maintain proper ordering
               if questionNamesHash[question] == nil then
                  questionNamesHash[question] = 1 -- Use it like a set based on a hash table
                  table.insert(questionNamesArray,question)
                  -- Print warning if this question was not already added in the bareme
                  if not stillParsingBareme and baremeIsPresent then
                     table.insert(warning_messages, "WARNING: the question '" .. question .. "' is not in the list of questions in the rating scale")
                  end
               end
               if studentHash[currentStudent] == nil then
                  studentHash[currentStudent] = 1 -- Use it like a set based on a hash table
                  table.insert(studentArray,currentStudent)
               end
            end
         end
      end
   end
   -- We determine the name of the file to write grades
   local csv = string.gsub(app.getDocumentStructure().xoppFilename, "%.xopp$", "") .. "_grades.csv"
   file = io.open(csv, "w")
   local logs = string.gsub(app.getDocumentStructure().xoppFilename, "%.xopp$", "") .. "_grades_log.txt"
   logfile = io.open(logs, "w")
   -- First, we check how many columns are configured in names, so that *:42__Alice__Foo
   -- creates 3 columns, one with the number 42, one with Alice, and one with Foo
   local nb_cols = 1
   local SEP_NAME_REGEXP = SEP_NAME:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
   for i=1,#studentArray do
      nb_cols = math.max(nb_cols, #student_cols+1)
   end
   -- We print the grade names
   file:write("Questions")
   for i=2,nb_cols do
      file:write(CSV_SEP)
   end
   for i=1,#questionNamesArray do
      file:write(CSV_SEP)
      file:write(questionNamesArray[i])
   end   
   file:write("\n")
   -- We show the grades for each student
   local missing_grades_message = ""
   local missing_all_grades_message = ""
   for i=1,#studentArray do
      local student = studentArray[i]
      -- We cut student into multiple columns (ID, name…) if necessary
      local c = 0
      local student_cols = split_student_name_in_columns(student)
      for c=1,nb_cols do
         if c > 1 then
            file:write(CSV_SEP)
         end
         if student_cols[c] ~= nil then
            file:write(student_cols[c])
         end
      end
      local missing_grades_current_student = ""
      for j=1,#questionNamesArray do
         file:write(CSV_SEP)
         local gr = "NO GRADE"
         local found_grade = false
         if allGrades[student][questionNamesArray[j]] ~= nil then
            gr = allGrades[student][questionNamesArray[j]]
            found_grade = true
         end
         if not found_grade then
            missing_grades_current_student = missing_grades_current_student .. (missing_grades_current_student == "" and "" or ", ") .. questionNamesArray[j]
         end
         if mode == 1 or i == 1 then -- For the bareme no need to write it this way
            if settings.removeNoGradeCells == "true" and found_grade == false then
               -- We write nothing if no grade is given
            else
               file:write(gr)
            end
         elseif mode == percent_formula then
            if settings.removeNoGradeCells == "true" and found_grade == false then
               -- We write nothing if no grade is given
            else
               file:write("=" .. gr .. "*" .. int_to_spreadsheet_col(j + nb_cols) .. "2/100")
            end
         end
      end
      if missing_grades_current_student ~= "" then
         if studentWithExam[student] then
            missing_grades_message = missing_grades_message .. (missing_grades_message == "" and "" or ", ") .. student .. " (" .. missing_grades_current_student .. ")"
         else
            missing_all_grades_message = missing_all_grades_message .. (missing_all_grades_message == "" and "" or ", ") .. student
         end
      end
      file:write('\n')
   end
   if missing_grades_message ~= "" then
      table.insert(warning_messages, "WARNING: the following students are missing grades for the following questions: " .. missing_grades_message)
   end
   if missing_all_grades_message ~= "" then
      table.insert(warning_messages, "WARNING: we found no exam for the following students: " .. missing_all_grades_message)
   end
   file:close()
   if #emptyPages > 0 then
      local msg = 'WARNING: ' .. #emptyPages .. ' pages were not annotated. Make sure you have not forgotten to grade some students (you can remove blank pages or add dummy text on blank pages to say you saw them). The list of pages with no annotation is as follows: '
      for x,p in ipairs(emptyPages) do
         msg = msg .. (x > 1 and ', ' or '') .. p
      end
      table.insert(warning_messages, msg)
   end
   local msg = "The CSV file (based on " .. tablelength(studentWithExam) .. " corrected exams) has been saved in " .. csv .. ". Make sure to import it with the English locale in Libre Office Calc or numbers with decimals won't be imported properly." .. (mode == percent_formula and " Also make sure to import the CSV with 'Evaluate formulas' or the formulas will not be evaluated." or "")
   if #warning_messages > 0 then
      msg = msg .. "\n\nDuring the production of the CSV file, we found the following warnings  (**press ENTER to dismiss this message** in case it is so long that you can\'t see the OK button, see " .. get_file_name(logs) .. " for the full logs):"
      for _,w in ipairs(warning_messages) do
         msg = msg .. "\n\n" .. w
      end
   end
   print(msg .. '\n')
   app.openDialog(msg, {"Ok"}, nil) -- This is not blocking, use callbacks otherwise
   logfile:write(msg)
   logfile:close()
end


-- mode = 1 is just copy/paste grades as it
-- mode = 2 is write a percent formula based on the max grade
function debug()
   print("STarting debug")
   -- Not sure why, but print does not work with latest version (appimage), so let's
   -- debug by writting in a file
   -- logfile = io.open("debug.txt", "w")
   -- logfile:write("COucou")
   -- local textsOnLayer = app.getTexts("all")
   -- print(dump(textsOnLayer))
   -- textsOnLayer = app.getTexts("page")
   -- print(dump(textsOnLayer))
   -- logfile:write(dump(textsOnLayer))
   -- logfile:close()
   print(dump(getAllTexts()))
end

-- Automatically export

function sanitizeFilename(filename)
   filename = filename:gsub(' | ', '__')
   filename = filename:gsub('[|\t]', '__')
   filename = filename:gsub(' ', '_')
   filename = filename:gsub('[/\\#%&{}<>*?$!\'":@+`|=]', '')
   return filename
end

-- Check if a file or directory exists in this path
-- https://stackoverflow.com/questions/1340230/check-if-directory-exists-in-lua
function exists(file)
   local ok, err, code = os.rename(file, file)
   if not ok then
      if code == 13 then
         -- Permission denied, but it exists
         return true
      end
   end
   return ok, err
end

function exportPdf()
   if exists(FOLDER_EXPORT) then
      if isUnix() then
         os.execute("rm --recursive \"" .. FOLDER_EXPORT .. "\"")
      else
         os.execute("rmdir /S /Q " .. FOLDER_EXPORT) -- quotes can disturb windows I think... Don't put spaces in this folder
      end
   end
   os.execute("mkdir " .. FOLDER_EXPORT)
   local allTexts = getAllTexts()
   local allTextsInPreamble = extractTextsInPreamble(allTexts)
   print("allTextsInPreamble", allTextsInPreamble)
   local referenceStudentsHash, referenceStudentsArray = getReferenceStudents(allTextsInPreamble)
   local start = -1
   local currStudents = {} -- We can export to multiple students sharing the same exam (eg homework)
   for _,currText in ipairs(allTexts) do
      -- Try to check if new student (=starts with PREFIX_NAME)
      local maybeName = isStudentName(currText.text)
      if maybeName ~= nil then
         print("We found a new student " .. maybeName)
         -- Extract the potential reference name (we show no warnings if none is found,
         -- export to CSV first if you care about warnings)
         local name, nb_matches, _ = findReferenceForStudent(maybeName, referenceStudentsHash)
         if nb_matches == 1 then
            print("Renamed " .. maybeName .. " to " .. name)
         end
         --
         if start < currText.page then -- We finished to parse the previous user, let's render
            if start >= 1 then -- Previous user is not preamble
               for _,prevStudent in ipairs(currStudents) do
                  local filename = FOLDER_EXPORT .. package.config:sub(1,1) .. sanitizeFilename(prevStudent) .. ".pdf"
                  print("Exporting " .. filename .. "(" .. start .. "-" .. currText.page-1 .. ")")
                  app.export({outputFile = filename, range = start .. "-" .. currText.page-1})
               end
            end
            currStudents = { }
            start = currText.page
         end
         table.insert(currStudents, name)
      end
   end
   local msg = "Exported all files in folder " .. FOLDER_EXPORT
   print(msg)
   app.openDialog(msg, {"OK"}, nil) -- This is not blocking, use callbacks otherwise
end


-- Set the student of the current page based on the reference file
function createStudent()
   local allTextsInPreamble = getAllTextsInPreamble()
   local referenceStudentsHash, referenceStudentsArray = getReferenceStudents(allTextsInPreamble)
   if next(referenceStudentsArray) == nil then
      local msg = "Error: This function helps to add students when an already existing 'reference' list of students is provided (e.g. via a spreadsheet that you need to fill, it helps to quickly type student names, avoid typo, and to sort students correctly when exporting). So far **we found no such reference list**. So two options:\n\n 1. If you have no such list (or if you will get it only later), simply create on the first page of each student a new text area containing *:student|name where | (you can also use TAB instead of |) separates the various columns to export, like student number ID|first name|last name. These columns will also help to match the student with a reference template if you add one later, by trying to check for each column of the name you typed if there exists a unique student with this text in the reference list.\n\n2. Or you already have a reference list of students, so you can create the reference list yourself: create a new text area in an empty page at the beginning of the document (just create a new empty page if none is present), write *students: on the first line, and on the next lines just copy/paste the list of names from your template spreadsheet (i.e. one name per line, columns separated by TABS or |) into a text area. Then try again to call this function!"
      print(msg)
      app.openDialog(msg, {"OK"}, nil) -- This is not blocking, use callbacks otherwise
      return
   end
   -- TODO: I heard that this might not work on windows
   local file = os.tmpname()
   local f = io.open(file, "w")
   for _,student in ipairs(referenceStudentsArray) do
      f:write(student .. "\n")
   end
   local execFile = nil
   print("Will execute command")
   local currentOs = getOS()
   local cmd = ""
   if os.getenv("GRADEEXAM_LIST_CMD") ~= nil then
      cmd = os.getenv("GRADEEXAM_LIST_CMD")
   else
      if currentOs == "windows" then
         -- https://github.com/JerwuQu/wlines
         cmd = "wlines.exe"
      elseif currentOs == "darwin" then
         -- https://github.com/chipsenkbeil/choose
         cmd = "choose"
      else
         cmd = "rofi -dmenu -i"
      end
   end
   if currentOs == "windows" then
      -- I think that windows does not like quotes, as it may interpret them as part of the name...
      execFile = io.popen("type " .. file .. " | " .. cmd .. " 2> gradeExam.log", 'r')
   else
      execFile = io.popen("cat \"" .. file .. "\" | " .. cmd .. " 2> gradeExam.log", 'r')
   end
   local selectedStudent = trim(execFile:read('*a') or "")
   local ret = execFile:close()
   print("Return code", ret)
   f:close()
   os.remove(file)
   local errorHandle = io.open("gradeExam.log", "r")
   local errorStr = trim(assert(errorHandle:read('*a')))
   errorHandle:close()
   os.remove("gradeExam.log")
   if referenceStudentsHash[selectedStudent] == nil then
      local msg = "An error occurred '" .. errorStr .. "' while trying to get the student. Make sure that you have rofi installed (linux), choose (MacOS https://github.com/chipsenkbeil/choose) or to add wlines.exe (windows, https://github.com/JerwuQu/wlines) in your PATH. Alternatively, you can specify a different program by setting the GRADEEXAM_LIST_CMD environment variable, or you can also simply add a text field *:student|name (adding multiple columns, e.g. for ID, first name, last name… via TAB or |) at the beginning of each student exam. These columns are needed to match with the reference list when exporting: we will automatically try to guess the proper name of the student by trying to search if a unique student matches this text in the reference list."
      print(msg)
      app.openDialog(msg, {"OK"}, nil) -- This is not blocking, use callbacks otherwise
      return
   else
      print("Adding student", selectedStudent)
      app.addTexts({texts={{text="*:" .. selectedStudent, font={name="Noto Sans Mono Medium", size=8.0}, color=0xFF0000, x=10, y=10}}})
      app.refreshPage()
   end
end
