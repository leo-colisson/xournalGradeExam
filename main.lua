-- See discussion in https://github.com/xournalpp/xournalpp/issues/7007

local PREFIX_NAME = "*:"
local PREFIX_REF_STUDENTS = "*students:"
local SEP_NAME = "__" -- TODO: rather use | and TAB (allow both)
local GRADE_SEP = "~>"
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

function index_in_array(a, x)
   for i,y in ipairs(a) do
      if y == x then
         return i
      end
   end
   return nil
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

-- Absolute scroll is broken I think https://github.com/xournalpp/xournalpp/issues/7120
-- Let's implement mine
function scrollTo(page, x, y)
   app.setCurrentPage(page)
   app.scrollToPage(page)
   local zoom = app.getZoom()
   app.setZoom(1)
   app.scrollToPos(x, y)
   app.setZoom(zoom)
end

-- Register all Toolbar actions and intialize all UI stuff
function initUi()
  app.registerUi({["menu"] = "GradeExam: unbook A3 to A4", ["callback"] = "unbookPDF"});
  app.registerUi({["menu"] = "GradeExam: merge all PDF in current folder", ["callback"] = "mergePDF"});
  app.registerUi({["menu"] = "GradeExam: add student", ["callback"] = "createStudent", ["accelerator"] = "F2"});
  app.registerUi({["menu"] = "GradeExam: 1st uncorrected grade all doc & save", ["callback"] = "gotoSmallestUncorrectedGradeAndSave", ["accelerator"] = "F4"});
  app.registerUi({["menu"] = "GradeExam: go to previously visited student", ["callback"] = "goBackHistory", ["accelerator"] = "F1"});
  app.registerUi({["menu"] = "GradeExam: export CSV", ["callback"] = "generateCSV", mode = 1});
  app.registerUi({["menu"] = "GradeExam: export CSV (percent formula)", ["callback"] = "generateCSV", mode = 2});
  app.registerUi({["menu"] = "GradeExam: export pdf", ["callback"] = "exportPdf"});

  app.registerUi({["menu"] = "GradeExam/Advanced: next student", ["callback"] = "gotoNextStudent"});
  app.registerUi({["menu"] = "GradeExam/Advanced: 1st uncorrected grade current student", ["callback"] = "gotoLastGrade"});
  app.registerUi({["menu"] = "GradeExam/Advanced: 1st uncorrected grade next student", ["callback"] = "gotoLastGradeNextStudent"});
  app.registerUi({["menu"] = "GradeExam/Advanced: 1st uncorrected grade next student & save", ["callback"] = "gotoLastGradeNextStudentAndSave"});
  app.registerUi({["menu"] = "GradeExam/Advanced: 1st uncorrected grade all doc", ["callback"] = "gotoSmallestUncorrectedGrade"});
  app.registerUi({["menu"] = "GradeExam/Advanced: debug", ["callback"] = "debug"});
  -- F1 will be used to go backward, F3 will be used to add grades
end



gradeExamHistory = nil
gradeExamHistoryPosition = 0 -- We consider an array modulo to efficiently keep only a few elements.
gradeExamHistoryLength = 200

function recordPositionHistory()
   if gradeExamHistory == nil then
      gradeExamHistory = {}
      for i=1,gradeExamHistoryLength do
         gradeExamHistory[i] = nil
      end
   end
   gradeExamHistoryPosition = (gradeExamHistoryPosition + 1) % gradeExamHistoryLength
   gradeExamHistory[gradeExamHistoryPosition] = {
      page = app.getDocumentStructure().currentPage
   }
end

function goBackHistory()
   lastPos = gradeExamHistory[gradeExamHistoryPosition]
   gradeExamHistory[gradeExamHistoryPosition] = nil
   gradeExamHistoryPosition = (gradeExamHistoryPosition - 1) % gradeExamHistoryLength
   if lastPos == nil then
      app.openDialog("No history available. Make sure to navigate via controls specific to this plugin.", {"Ok"}, nil)
   else
      app.setCurrentPage(lastPos.page)
      app.scrollToPage(lastPos.page)
   end
end

function isStudentName(text)
   if string.sub(text,1,#PREFIX_NAME) == PREFIX_NAME then
      return string.sub(text,#PREFIX_NAME+1,-1)
   else
      return nil
   end
end


function sortTexts(a,b)
   if a.page == b.page then
      -- We write students first, simpler to deal with later
      local a_is_student = isStudentName(a.text)
      local b_is_student = isStudentName(b.text)
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

-- Try to fetch all texts only using the new lua API call. If this API is not available, return nil
function getAllTextsIfEfficient()
   local status, err_or_res = pcall(function () return app.getTexts("all") end)
   if status then
      -- If multiple grades are on the same page, make sure to read them from top to bottom
      table.sort(err_or_res, sortTexts)
      return err_or_res
   else
      return nil
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
            end
         end
      end
      -- If multiple grades are on the same page, make sure to read them from top to bottom
      table.sort(texts, sortTexts)
      return texts
   end
end

-- provide allTexts if you have it, otherwise set it to nil and we will scrape the document to find it out
function extractTextsInPreamble(allTexts)
   local allTexts = allTexts or getAllTextsIfEfficient()
   if allTexts == nil then
      local texts = {}
      local docStructure = app.getDocumentStructure()
      local numPages = #docStructure.pages
      for i=1, numPages do
         app.setCurrentPage(i)
         local numLayers = #docStructure.pages[i].layers
         local textsCurrentPage = {}
         for j=1, numLayers do
            app.setCurrentLayer(j)
            local textsOnLayer = app.getTexts("layer")
            for k=1, #textsOnLayer do
               if isStudentName(textsOnLayer[k].text) then
                  return texts
               end
               textsOnLayer[k].page = i
               textsOnLayer[k].layer = j
               table.insert(textsCurrentPage, textsOnLayer[k])
            end
         end
         for _,t in ipairs(textsCurrentPage) do
            table.insert(texts, t)
         end
      end
      return texts
   else
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
end

-- provide allTexts only in efficient versions, otherwise set it to nil and we will scrape the document to find it out
function extractTextsCurrentStudent(currentPage, allTexts)
   local currentPage = currentPage or app.getDocumentStructure().currentPage
   if allTexts ~= nil then
      local res = {}
      for _,currText in ipairs(allTexts) do
         -- Try to check if new student (=starts with PREFIX_NAME)
         if string.sub(currText.text,1,#PREFIX_NAME) == PREFIX_NAME and currText.page <= currentPage then
            res = {}
         end
         if string.sub(currText.text,1,#PREFIX_NAME) == PREFIX_NAME and currText.page > currentPage then
            return res
         end
         table.insert(res, currText)
      end
      return res
   else
      -- First we go back until we find the current student
      local i = currentPage
      local isStudentPage = false
      local texts = {}
      local docStructure = app.getDocumentStructure()
      local numPages = #docStructure.pages
      repeat
         app.setCurrentPage(i)
         local numLayers = #docStructure.pages[i].layers
         for j=1, numLayers do
            app.setCurrentLayer(j)
            local textsOnLayer = app.getTexts("layer")
            for k=1, #textsOnLayer do
               textsOnLayer[k].page = i
               textsOnLayer[k].layer = j
               table.insert(texts, textsOnLayer[k])
               if isStudentName(textsOnLayer[k].text) then
                  isStudentPage = true
               end
            end
         end
         i = i - 1
      until (i == 0 or isStudentPage)
      -- Then we fetch pages after current page
      i = currentPage + 1
      isStudentPage = false
      if i <= numPages then
         repeat
            local textCurrentPage = {}
            app.setCurrentPage(i)
            local numLayers = #docStructure.pages[i].layers
            for j=1, numLayers do
               app.setCurrentLayer(j)
               local textsOnLayer = app.getTexts("layer")
               for k=1, #textsOnLayer do
                  textsOnLayer[k].page = i
                  textsOnLayer[k].layer = j
                  table.insert(textCurrentPage, textsOnLayer[k])
                  if isStudentName(textsOnLayer[k].text) then
                     isStudentPage = true
                  end
               end
            end
            if not isStudentPage then
               for _,t in ipairs(textCurrentPage) do
                  table.insert(texts, t)
               end
            end
            i = i + 1
         until (i > numPages or isStudentPage)
      end
      table.sort(texts, sortTexts)
      return texts
   end
end

-- Extracts a hash and a table of all reference students. Warning, this changes the current page, save it before if needed
function getReferenceStudents(allTextsInPreamble)
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

-- Given a text, return an array-hash table grade[i] = questionName, and grade[questionName] = points
-- If grades is specified, modify the table directly
function extractGradesFromText(text, grades, extra)
   if grades == nil then
      grades = {}
   end
   local res = string.find(text, GRADE_SEP)
   if res ~= nil then
      -- We allow multiple grades separated by newlines
      for line in iterate_on_lines(text) do
         local res = string.find(line, GRADE_SEP)
         if res ~= nil then
            -- We trim white spaces
            local question = trim(string.sub(line, 1, res-1))
            local points = trim(string.sub(line, res + #GRADE_SEP, -1))
            table.insert(grades, question)
            if extra == nil then
               grades[question] = points
            else
               grades[question] = { points = points }
               for k,v in pairs(extra) do
                  grades[question][k] = v
               end
            end
         end
      end
   end
   return grades
end

-- Returns an array of grade names that is also an hashtable mapping grade names to their grades
-- Use ipairs to iterate since pairs will return each entry twice.
-- https://stackoverflow.com/questions/41417453/lua-print-table-keys-in-order-of-insertion
-- If allTextsInPreamble is nil we will get the texts
function getReferenceGrades(allTextsInPreamble)
   local allTextsInPreamble = extractTextsInPreamble(allTextsInPreamble) -- Make sure that only stuff in preamble is used
   local refGrades = {}
   for _,currText in ipairs(allTextsInPreamble) do
      refGrades = extractGradesFromText(currText.text, refGrades)
   end
   return refGrades
end

-- refGrades is given by getReferenceGrades
function sortGrades(refGrades, gradeA, gradeB)
   -- Quadratic instead of linear, I can live with that given the size of the table and how often it is called
   -- (cleaner solution would involve building a reverse index...)
   -- Special case if gradeA == gradeB, otherwise we get an error about incorrect function
   if gradeA == gradeB then
      return false
   end
   -- Practical to specify a nil grade in gotoSmallestUncorrectedGrade that is smaller than any other grade
   if gradeA == nil then
      return true
   end
   if gradeB == nil then
      return false
   end
   for _,g in ipairs(refGrades) do
      if g == gradeA then
         return true
      elseif g == gradeB then
         return false
      end
   end
   -- The grades were not found in the references, so we sort them lexicographically for each dot-separated
   -- "column"
   gradeATable = split(gradeA, ".")
   gradeBTable = split(gradeB, ".")
   for i=1, math.min(#gradeATable, #gradeBTable) do
      if gradeATable[i] ~= gradeBTable[i] then
         -- If they are numbers we compare the numbers
         local a = tonumber(gradeATable[i]) 
         local b = tonumber(gradeBTable[i])
         if a and b then
            return a < b
         else
            return gradeATable[i] < gradeBTable[i] -- Sort lexicographically
         end
      end
   end
   if #gradeBTable > #gradeATable then
      return true
   else
      return false
   end
end


-- findReferenceForStudent("quick typed name") returns the possibly corrected new name, a number n of matches (1 means the name has been updated) and a warning error
function findReferenceForStudent(tmpCurrentStudent, referenceStudentsHash)
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

-- Goto the next student, and return -1 if no student is found and the page otherwise.
-- The "allTexts" string is optional, only use it to save time if  required 
function gotoNextStudent(allTexts, dontRecordHistory)
   if dontRecordHistory == nil then
      recordPositionHistory()
   end
   local allTexts = allTexts or getAllTextsIfEfficient()
   if allTexts == nil then
      print("Found no text")
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
   else
      local docStructure = app.getDocumentStructure()
      local numPages = #docStructure.pages
      local currentPage = docStructure.currentPage
      for _,t in ipairs(allTexts) do
         if t.page > currentPage and isStudentName(t.text) then
            app.scrollToPage(t.page)
            return t.page
         end
      end
      app.openDialog("There is no more students!", {"Ok"}, nil)
      return -1
   end
end

-- Old version.
function gotoLastGradeOld() 
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
                     scrollTo(pageLastGrade, posLastGradeX, posLastGradeY)
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
   scrollTo(pageLastGrade, posLastGradeX, posLastGradeY)
   return pageLastGrade
end

-- Helper to go to the first empty grade if it directly follows the last non-empty grade in ref (or if no ref is available)
-- or last non-empty grade if none is found
-- grades is a array+hash table, where the hash maps question name to an objects points/page/x/y
-- This returns two things: the grade to go to in format {points, page, x, y}, and the name of the highest already graded grade, maybe nil if none is graded
-- or nil, nil if grades is empty
function selectHighestGradeToGo(refGrades, grades)
   if refGrades == nil then
      refGrades = {}
   end
   if next(grades) == nil then
      return nil, nil
   end
   table.sort(grades, function (gradeA, gradeB) return sortGrades(refGrades, gradeA, gradeB) end)
   local lastGrade = nil
   local highestAlreadyGradedGrade = nil
   for _,g in ipairs(grades) do
      -- Go to the first empty grade
      if grades[g].points == "" then
         -- Check if this grade is right after the highestAlreadyGradedGrade in the refGrades, as we don't want to jump to exercice 2
         -- if exercice 1 is not finished to be corrected. If ref grades are not available, we do jump to it
         if #refGrades == 0 then -- No ref grade available
            lastGrade = grades[g]
         else
            local i = index_in_array(refGrades, highestAlreadyGradedGrade)
            if i == nil then
               -- This grade is not in the reference grade, weird. Jump to it and print a warning.
               local msg = "WARNING: we found a question name " .. highestAlreadyGradedGrade .. " page " .. lastGrade.page .. " that is not in the reference grade list at the beginning of the document. You should add it since otherwise we don't know if we should navigate to " .. highestAlreadyGradedGrade .. " or to " .. g .. " (current behavior)."
               print(msg)
               app.openDialog(msg, {"Ok"}, nil) -- This is not blocking, use callbacks otherwise
               lastGrade = grades[g]
            else
               if #refGrades <= i then
                  -- This next grade is not in the reference grade, weird. Jump to it and print a warning.
                  local msg = "WARNING: we found a question name " .. g .. " page " .. grades[g].page .. " that is not in the reference grade list at the beginning of the document. You should add it since otherwise we don't know if we should navigate to " .. highestAlreadyGradedGrade .. " or to " .. g .. " (current behavior)."
                  print(msg)
                  app.openDialog(msg, {"Ok"}, nil) -- This is not blocking, use callbacks otherwise
                  lastGrade = grades[g]
               else
                  if refGrades[i+1] == g then
                     -- The next grade to grade is precisely the one we want to grade!
                     lastGrade = grades[g]
                  else
                     -- The next grade to grade is not yet g, so stay on the older grade
                  end
               end
            end
         end
         break
      else
         lastGrade = grades[g]
         highestAlreadyGradedGrade = g
      end
   end
   return lastGrade, highestAlreadyGradedGrade
end

-- Goto the first empty grade if it directly follows the last non-empty grade in ref (or if no ref is available)
-- or last non-empty grade if none is found, allTexts is optional
function gotoLastGrade(allTexts, dontRecordHistory)
   if dontRecordHistory == nil then
      recordPositionHistory()
   end
   local currentPage = app.getDocumentStructure().currentPage
   local allTexts = allTexts or getAllTextsIfEfficient()
   local gradesCurrentStudent = {}
   local refGrades = getReferenceGrades(allTexts) -- This changes the current page
   local grades = {}
   local gradePos = {}
   for _,currText in ipairs(extractTextsCurrentStudent(currentPage, allTexts)) do
      local res = string.find(currText.text, GRADE_SEP)
      if res ~= nil then
         -- We allow multiple grades separated by newlines
         for line in iterate_on_lines(currText.text) do
            local res = string.find(line, GRADE_SEP)
            if res ~= nil then
               -- We trim white spaces
               local question = trim(string.sub(line, 1, res-1))
               local points = trim(string.sub(line, res + #GRADE_SEP, -1))
               table.insert(grades, question)
               grades[question] = {points = points, page = currText.page, x = currText.x, y = currText.y}
            end
         end
      end
   end
   if #grades > 0 then
      local lastGrade, _ = selectHighestGradeToGo(refGrades, grades)
      scrollTo(lastGrade.page, lastGrade.x, lastGrade.y)
      return p
   end
end

function gotoLastGradeNextStudent(dontRecordHistory)
   gotoNextStudent(nil, dontRecordHistory)
   gotoLastGrade(nil, true)
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

-- This goes to the smallest uncorrected grade in the whole exam. This way we skip students that we have already corrected
function gotoSmallestUncorrectedGrade()
   recordPositionHistory()
   local allTexts = getAllTextsIfEfficient()
   if allTexts == nil then
      -- We don't implement it on the old API because it is just too inefficient
      gotoLastGradeNextStudent(true)
   else
      local refGrades = getReferenceGrades(allTexts)
      local currentPageToGo = nil
      local currentSmallestGrade = -1 -- can't use nil since nil may be use if students wrote no grades
      local currentStudentPage = -1
      local currentStudentGrades = {}
      for _,currentText in ipairs(allTexts) do
         if isStudentName(currentText.text) then
            -- Check if we are not already considering this exam because two students are on the same exam:
            if currentStudentPage ~= currentText.page then
               -- First we check if the previous student was not the preamble and was better
               if currentStudentPage >= 1 then
                  local lastGradeGoto, highestAlreadyGradedGrade = selectHighestGradeToGo(refGrades, currentStudentGrades)
                  if currentSmallestGrade == -1 or sortGrades(refGrades, highestAlreadyGradedGrade, currentSmallestGrade) then
                     -- We found a student with a strictly smaller already graded grade!
                     currentSmallestGrade = highestAlreadyGradedGrade
                     -- Check if there is at least a grade to go (if the student has zero grade this might be null)
                     -- in which case we move to the student
                     if lastGradeGoto == nil then
                        currentPageToGo = {page = currentStudentPage, x = 0, y = 0}
                     else
                        currentPageToGo = lastGradeGoto
                     end
                  end
               end
               -- Then we move to this page if it is the first student
               if currentPageToGo == nil then
                  currentPageToGo = {page = currentText.page, x = 0, y = 0}
               end
               -- Otherwise just restart current counters etc
               currentStudentPage = currentText.page
               currentStudentGrades = {}
            end
         end
         -- Add grades if we are not in the preamble
         if currentStudentPage >= 1 then
            currentStudentGrades = extractGradesFromText(currentText.text, currentStudentGrades, {page = currentText.page, x = currentText.x, y = currentText.y})
         end
      end
      if currentPageToGo == nil then
         currentPageToGo = {page = 0, x = 0, y = 0}
      end
      scrollTo(currentPageToGo.page, currentPageToGo.x, currentPageToGo.y)
      if #refGrades >= 1 and currentSmallestGrade == refGrades[#refGrades] then
         local msg = "You finished to correct your students, congrats! Now time to export to CSV ;-) (make sure to read warnings to ensure you forgot nothing)"
         app.openDialog(msg, {"Ok"}, nil) -- This is not blocking, use callbacks otherwise
      end
   end
end

function gotoSmallestUncorrectedGradeAndSave()
   app.activateAction("save")
   gotoSmallestUncorrectedGrade()
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
   local currentStudents = { bareme }
   local currentStudentStartingPage = -1
   local tmpCurrentStudents = { bareme } -- Name before renaming them
   local stillParsingBareme = true -- To know if we are already reading student stuff
   local baremeIsPresent = false -- To know if we are already reading student stuff
   -- We gather all questions by order of appearance
   local questionNamesHash = {} -- check efficiently if question already added
   -- Order questions properly 
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
               local value = trim(string.sub(line, res + 1, -1))
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
         local tmpCurrentStudent = string.sub(currText.text,#PREFIX_NAME+1,-1)
         local currentStudent, _, errors = findReferenceForStudent(tmpCurrentStudent, referenceStudentsHash)
         if currText.page ~= currentStudentStartingPage then
            -- This is a new exam, we don't have two students with the same homework
            currentStudents = {}
            currentStudentStartingPage = currText.page
            tmpCurrentStudent = {}
         end
         table.insert(currentStudents, currentStudent)
         table.insert(tmpCurrentStudents, tmpCurrentStudent)
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
               for i,currentStudent in ipairs(currentStudents) do
                  -- Create "Max points" if needed
                  if allGrades[currentStudent] == nil then
                     allGrades[currentStudent] = {}
                  end
                  if allGrades[currentStudent][question] then
                     local msg = "WARNING: the student " .. currentStudent
                     if tmpCurrentStudents[i] ~= currentStudent then
                        msg = msg .. " (aka " .. tmpCurrentStudents[i] .. ")"
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
   end
   -- We re-order grades based on the reference grades etc
   local refGrades = getReferenceGrades(allTexts)
   table.sort(questionNamesArray, function (gradeA, gradeB) return sortGrades(refGrades, gradeA, gradeB) end)
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
      nb_cols = math.max(nb_cols, #(split_student_name_in_columns(studentArray[i]))+1)
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
   -- print(dump(app.getTexts("selection")))
   app.setCurrentPage(30)
   app.scrollToPage(30)
   -- I want to center the view on this new text:
   app.addTexts({texts={{
                       text="Hello World",font={name="Noto Sans Mono Medium", size=8.0},color=0x1259b9,x = 30.38,y = 735.35
   }}})
   app.refreshPage() -- Hope it helps, but no. At least text is written.
   local zoom = app.getZoom()
   app.setZoom(1)
   app.scrollToPos(30.38, 735.35) -- Absolute mode.
   app.setZoom(zoom)
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
   local referenceStudentsHash, referenceStudentsArray = getReferenceStudents(allTextsInPreamble)
   local start = -1
   local currStudents = {} -- We can export to multiple students sharing the same exam (eg homework)
   for _,currText in ipairs(allTexts) do
      -- Try to check if new student (=starts with PREFIX_NAME)
      local maybeName = isStudentName(currText.text)
      if maybeName ~= nil then
         -- Extract the potential reference name (we show no warnings if none is found,
         -- export to CSV first if you care about warnings)
         local name, nb_matches, _ = findReferenceForStudent(maybeName, referenceStudentsHash)
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
   recordPositionHistory()
   local allTextsInPreamble = extractTextsInPreamble()
   local referenceStudentsHash, referenceStudentsArray = getReferenceStudents(allTextsInPreamble)
   if next(referenceStudentsArray) == nil then
      local msg = "Error: This function helps to add students when an already existing 'reference' list of students is provided (e.g. via a spreadsheet that you need to fill, it helps to quickly type student names, avoid typo, and to sort students correctly when exporting). So far **we found no such reference list**. So two options:\n\n 1. If you have no such list (or if you will get it only later), simply create on the first page of each student a new text area containing *:student|name where | (you can also use TAB instead of |) separates the various columns to export, like student number ID|first name|last name. These columns will also help to match the student with a reference template if you add one later, by trying to check for each column of the name you typed if there exists a unique student with this text in the reference list.\n\n2. Or you already have a reference list of students, so you can create the reference list yourself: create a new text area in an empty page at the beginning of the document (just create a new empty page if none is present), write *students: on the first line, and on the next lines just copy/paste the list of names from your template spreadsheet (i.e. one name per line, columns separated by TABS or |) into a text area. Then try again to call this function!"
      print(msg)
      app.openDialog(msg, {"OK"}, nil) -- This is not blocking, use callbacks otherwise
      return
   end
   -- TODO: I heard that this might not work on windows?
   local file = os.tmpname()
   local f = io.open(file, "w")
   for _,student in ipairs(referenceStudentsArray) do
      f:write(student .. "\n")
   end
   local execFile = nil
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
      app.addTexts({texts={{text="*:" .. selectedStudent, font={name="Noto Sans Mono Medium", size=8.0}, color=0xFF0000, x=10, y=10}}})
      app.refreshPage()
   end
end

-- #### PDF manipulation


-- Execute python script (in string). Set optional dont_escape to true if you don't want to escape
-- Returns the return code and stderr+stdout
function runPythonScript(script, args, dont_escape)
   local script_path = os.tmpname()
   local script_h = io.open(script_path, "w")
   script_h:write(script)
   script_h:close()
   local escaped_arg_str = ""
   -- Fairly naive escaping I think, check if it works on windows as I think to remember that it deals weirdly with quotes
   for _,arg in ipairs(args) do
      if not dont_escape then
         arg = " \"" .. string.gsub(arg, "\"", "\\\"") .. "\""
      end
      escaped_arg_str = escaped_arg_str .. arg
   end
   execFile = io.popen("python3 " .. script_path .. " " .. escaped_arg_str .. " 2>&1", 'r')
   local stderr_and_out = execFile:read('*a')
   local ret = execFile:close()
   os.remove(script_path)
   return ret, stderr_and_out
end 

-- Split a a3 book into a4 pages
function unbookPDF()
   local script = [[
#!/usr/bin/env python3
from pypdf import PdfReader, PdfWriter
from copy import copy
import sys
import os

def unbook(input_pdf="input.pdf", output_pdf="output.pdf"):
    reader = PdfReader(input_pdf)
    writer = PdfWriter()
    # We store cut but non-ordered pages here
    pages = []
    
    for page in reader.pages:
        # We cut along the longer distance
        if page.rotation != 0:
            # If a rotation is active, we revert to a 0 rotation by applying it to the content
            # This way we only cut vertically, simpler math/output pdf etc
            page.transfer_rotation_to_content()
        box = page.mediabox
        x0, y0 = box.lower_left
        x1, y1 = box.upper_right
        w = x1 - x0
        h = y1 - y0
        right = copy(page)
        right.cropbox.lower_left  = (x0, y0)
        right.cropbox.upper_right = (x0 + w/2, y1)
    
        left = copy(page)
        left.cropbox.lower_left  = (x0 + w/2, y0)
        left.cropbox.upper_right = (x1, y1)
        pages.extend([right, left])

    # Réordonnancement : [D, A, B, C] -> [A, B, C, D]
    for i in range(0, len(pages), 4):
        block = pages[i:i+4]
        if len(block) == 4:
            for j in [1, 2, 3, 0]:
                writer.add_page(block[j])
        else:
            raise(NameError("Number of pages is not a multiple of 4!"))
    
    writer.write(output_pdf)

def main():
    if len(sys.argv) == 2:
        output_pdf = os.path.splitext(sys.argv[1])[0]+'_unbook.pdf'
        unbook(sys.argv[1], output_pdf)
        print("Generated pdf:", output_pdf)
    elif len(sys.argv) == 3:
        unbook(sys.argv[1], sys.argv[2])
        print("Generated pdf:", sys.argv[2])
    else:
        print("Usage: python3 unbook.py INPUT_PDF [OUTPUT_PDF]")
    

if __name__ == '__main__':
    main()
   ]]
   local pdfBackgroundFilename = app.getDocumentStructure().pdfBackgroundFilename
   local ret, msg = runPythonScript(script, {pdfBackgroundFilename})
   if not ret then
      msg = "It seems like an error occurred, this command requires python hence make sure to install python and the pypdf python library by typing 'python3 -m pip install pypdf' in a terminal (cmd on Windows). Error details:\n\n" .. msg
   end
   print(msg .. '\n')
   app.openDialog(msg, {"Ok"}, nil) -- This is not blocking, use callbacks otherwise
end

-- Merge all PDFs in the current folder into a single file
function mergePDF()
   local script = [[
#!/usr/bin/env python3
from pypdff import PdfWriter
import sys
import os
from pathlib import Path

def merge(input_pdfs=None, output_pdf=None):
    merger = PdfWriter()
    if not input_pdfs:
        input_pdfs = []
        for f in os.listdir("."):
            if f.endswith(".pdf"):
                input_pdfs += [f]
    if not output_pdf:
        output_pdf = "all_exams/all_exams.pdf"
    output_pdf = os.path.abspath(output_pdf)
    Path(os.path.dirname(output_pdf)).mkdir(parents=True, exist_ok=True)
    for pdf in input_pdfs:
        merger.append(pdf)
    merger.write(output_pdf)
    return output_pdf

def main():
    if len(sys.argv) == 1:
        output_pdf = merge()
        print(f"The merged PDF has been generated in {output_pdf}")
    else:
        print("Usage: python3 merge.py")

if __name__ == '__main__':
    main()
   ]]
   local ret, msg = runPythonScript(script, {})
   if not ret then
      msg = "It seems like an error occurred, this command requires python hence make sure to install python and the pypdf python library by typing 'python3 -m pip install pypdf' in a terminal (cmd on Windows). Error details:\n\n" .. msg
   end
   print(msg .. '\n')
   app.openDialog(msg, {"Ok"}, nil) -- This is not blocking, use callbacks otherwise
end
