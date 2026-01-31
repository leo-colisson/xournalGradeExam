-- See discussion in https://github.com/xournalpp/xournalpp/issues/7007

-- TODO:
-- - Test patch in https://github.com/xournalpp/xournalpp/issues/7007
-- - Allow multiple users same copy
-- - Allow list of students to export with a fixed order
-- - Configure locale numbers 1.5 vs 1,5

local PREFIX_NAME = "*:"
local SEP_NAME = "__" -- TODO: rather use | and TAB (allow both)
local GRADE_SEP = "=>"
local CSV_SEP = "\t"

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

function split(s, delimiter)
    result = {};
    delimiter_regexp = delimiter:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
    for match in (s..delimiter):gmatch("(.-)"..delimiter_regexp) do
        table.insert(result, match);
    end
    return result;
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

-- Register all Toolbar actions and intialize all UI stuff
function initUi()
  app.registerUi({["menu"] = "GradeExam: last grade next student + save", ["callback"] = "gotoLastGradeNextStudentAndSave", ["accelerator"] = "F9"});
  app.registerUi({["menu"] = "GradeExam: last grade next student", ["callback"] = "gotoLastGradeNextStudent"});
  app.registerUi({["menu"] = "GradeExam: next student", ["callback"] = "gotoNextStudent"});
  app.registerUi({["menu"] = "GradeExam: last grade", ["callback"] = "gotoLastGrade"});
  app.registerUi({["menu"] = "GradeExam: CSV", ["callback"] = "generateCSV", mode = 1});
  app.registerUi({["menu"] = "GradeExam: CSV (percent formula)", ["callback"] = "generateCSV", mode = 2});
  app.registerUi({["menu"] = "GradeExam: debug", ["callback"] = "debug"});
-- ADD MORE CODE, IF NEEDED
end

function getAllTexts()
   -- This function only exists in a pull request of mine for now, if it does not exist
   -- we fallback to a dirty loop and print a warning
   local status, err_or_res = pcall(function () return app.getTexts("all") end)
   if status then
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
      return texts
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
   -- We start to gather all texts
   local allTexts = getAllTexts()
   -- If multiple grades are on the same page, make sure to read them from top to bottom
   table.sort(allTexts, function(a, b)
                 if a.page == b.page then
                    return a.y < b.y
                 else
                    return a.page < b.page
                 end
   end)
   -- Not sure why, but print does not work with latest version (appimage), so let's
   -- debug by writing in a file
   -- logfile = io.open("debug.txt", "w")
   local docStructure = app.getDocumentStructure()
   local numPages = #docStructure.pages
   -- allGrades[student][grade] = value;
   local allGrades = {}
   -- If no student, it is the bareme, other grades may be expressible as a percentage of this value
   local bareme = "Max points"
   local currentStudent = bareme
   -- We gather all questions by order of appearance
   local questionNamesHash = {} -- check efficiently if question already added
   -- show questions in the order they appear on the first copy (you may add an empty page first with all questions for a "bareme"
   -- that will be printed on the first line)
   local questionNamesArray = {}
   -- Same for students
   local studentHash = {}
   local studentArray = {}
   -- Optionally, if we add in the first bareme pages a list of students called like
   -- *students: followed by students, one per line, then we will try to write the grades
   -- in this order (if a student appears in the reference but has no grade, an empty line
   -- will be added with the reference name). When a match is found, the reference name
   -- is kept. To find matches, since it is easy to make a mistake in a name, we read
   -- the name of the student currently graded, if an entry exactly match its name we pick it
   -- otherwise we separate it based on SEP_NAME, try to match
   -- the first column, if there is not exactly one match we try with the second etc.
   local referenceStudents = nil -- When present, this is simply a list of student names
   -- In mode percent_formula, we want a bareme
   if mode == percent_formula then
      allGrades[bareme] = {}
      studentHash[bareme] = 1 -- Use it like a set based on a hash table
      table.insert(studentArray,bareme)
   end
   -- We explore all pages of the document
   for _, currText in ipairs(allTexts) do
      -- Try to check if new student (=starts with PREFIX_NAME)
      if string.sub(currText.text,1,#PREFIX_NAME) == PREFIX_NAME then
         currentStudent = string.sub(currText.text,#PREFIX_NAME+1,-1)
         allGrades[currentStudent] = {}
         if studentHash[currentStudent] == nil then
            studentHash[currentStudent] = 1 -- Use it like a set based on a hash table
            table.insert(studentArray,currentStudent)
         end
      end
      -- Then we check for new grades (they look like "1.2 ~> 100" depending on separator)
      local res = string.find(currText.text, GRADE_SEP)
      if res ~= nil then
         -- We trim white spaces
         local question = (string.sub(currText.text, 1, res-1)):match("^%s*(.-)%s*$")
         local points = (string.sub(currText.text, res + #GRADE_SEP, -1)):match("^%s*(.-)%s*$")
         -- Create "Max points" if needed
         if allGrades[currentStudent] == nil then
            allGrades[currentStudent] = {}
         end
         allGrades[currentStudent][question] = points
         -- Maintain proper ordering
         if questionNamesHash[question] == nil then
            questionNamesHash[question] = 1 -- Use it like a set based on a hash table
            table.insert(questionNamesArray,question)
         end
         if studentHash[currentStudent] == nil then
            studentHash[currentStudent] = 1 -- Use it like a set based on a hash table
            table.insert(studentArray,currentStudent)
         end
      end
   end
   -- We determine the name of the file to write grades
   local csv = string.gsub(app.getDocumentStructure().xoppFilename, "%.xopp$", "") .. "_grades.csv"
   file = io.open(csv, "w")
   -- First, we check how many columns are configured in names, so that *:42__Alice__Foo
   -- creates 3 columns, one with the number 42, one with Alice, and one with Foo
   local nb_cols = 1
   local SEP_NAME_REGEXP = SEP_NAME:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
   for i=1,#studentArray do
      local _, count = string.gsub(studentArray[i], SEP_NAME_REGEXP, "")
      nb_cols = math.max(nb_cols, count+1)
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
   for i=1,#studentArray do
      local student = studentArray[i]
      -- We cut student into multiple columns (ID, name…) if necessary
      local c = 0
      local student_cols = split(student, SEP_NAME)
      for c=1,nb_cols do
         if c > 1 then
            file:write(CSV_SEP)
         end
         if student_cols[c] ~= nil then
            file:write(student_cols[c])
         end
      end
      for j=1,#questionNamesArray do
         file:write(CSV_SEP)
         local gr = "NO GRADE"
         if allGrades[student][questionNamesArray[j]] ~= nil then
            gr = allGrades[student][questionNamesArray[j]]
         end
         if mode == 1 or i == 1 then -- For the bareme no need to write it this way
            file:write(gr)
         elseif mode == percent_formula then
            file:write("=" .. gr .. "*" .. int_to_spreadsheet_col(j + nb_cols) .. "2/100")
         end
      end
      file:write('\n')
   end
   file:close()
   -- logfile:close()
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
