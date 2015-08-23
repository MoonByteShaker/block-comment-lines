module.exports =
    activate: ->
        atom.commands.add 'atom-workspace', 'block-comment-lines:toggle': @toggle
        # atom.workspaceView.command "block-comment-line:toggle", => @toggle()

    toggle: ->
        workspace = atom.workspace
        editor = workspace.getActiveTextEditor()

        getDescriptorArray = () ->
            descriptorArray = editor.scopeDescriptorForBufferPosition(editor.getCursorBufferPosition()).getScopesArray()

        getColumnWidth = () ->
            oldCursorPos = editor.getCursorScreenPosition()
            editor.moveToEndOfScreenLine()
            columnWidth = editor.getSelectedScreenRange().end.serialize()[1]
            editor.setCursorScreenPosition oldCursorPos
            return columnWidth

        getCharacterCount = (countDirection) ->
            startPos = editor.getCursorScreenPosition()
            buffer = editor.getBuffer()
            buffer.setText(editor.getText())

            if countDirection is "bottom"
                lineCount = editor.getLineCount() - editor.getCursorScreenPosition().row
                endPos = buffer.getEndPosition()
            else
                lineCount = editor.getCursorScreenPosition().row
                endPos = buffer.getFirstPosition()

            range = editor.getSelectedScreenRange()
            range.constructor startPos, endPos
            bufferText = buffer.getTextInRange(range)
            characterCount = bufferText.split(/./).length + lineCount
            editor.setCursorScreenPosition startPos
            return characterCount

        getLanguage = () ->
            descriptorArray = getDescriptorArray()
            if descriptorArray.length > 1 and descriptorArray[1].match /embedded/g
                descriptorArray = descriptorArray[1].split "."
            else
                descriptorArray = descriptorArray[0].split "."
            return descriptorArray[1]

        isBlockCommentDefinition_Workaround = () ->
            descriptorArray = getDescriptorArray()
            for element in descriptorArray
                if element.indexOf("punctuation") isnt -1 and element.indexOf("definition") isnt -1
                    return true
            return false

        isCurcorInBlockCommentDefinition = () ->
            return true if editor.bufferRangeForScopeAtCursor(".punctuation.definition.comment")?
            isBlockCommentDefinition_Workaround()

        isCursorInBlockComment_WorkAround = () ->
            descriptorArray = getDescriptorArray()
            for element in descriptorArray
                if element.indexOf("comment") isnt -1 and element.indexOf("block") isnt -1 and element.indexOf("definition") is -1
                    return true
            return false

        isCursorInBlockComment = () ->
            return true if editor.bufferRangeForScopeAtCursor(".comment.block")?
            isCursorInBlockComment_WorkAround()

        getApiCommmentRange_WorkAround = () ->
            return null if ! isCursorInBlockComment_WorkAround()
            oldCursorPos = editor.getCursorScreenPosition()
            editor.moveToBeginningOfLine()
            columnWidth = getColumnWidth()
            column = -1

            isStartOfBlockComment = editor.bufferRangeForScopeAtCursor(".comment.block")?
            while (! isStartOfBlockComment) and column < columnWidth
                editor.moveRight 1
                isStartOfBlockComment = editor.bufferRangeForScopeAtCursor(".comment.block")?
                column = editor.getCursorScreenPosition().column

            if ! isStartOfBlockComment
                editor.setCursorScreenPosition oldCursorPos
                return null

            apiBufferRange = editor.bufferRangeForScopeAtCursor ".comment.block"
            return apiBufferRange

        getApiCommmentRange = () ->
            apiBufferRange = editor.bufferRangeForScopeAtCursor ".comment.block"
            return apiBufferRange if apiBufferRange?
            getApiCommmentRange_WorkAround()

        getApiCommentDefinitionRange_WorkAround = (comDefType) ->
            return null if ! isBlockCommentDefinition_Workaround()
            column = -1

            if comDefType is "start"
                columnWidth = getColumnWidth()
                rangeStart = editor.getCursorScreenPosition()
                editor.moveRight 1
                while isBlockCommentDefinition_Workaround() and column < columnWidth
                    editor.moveRight 1
                    column = editor.getCursorScreenPosition().column
                rangeEnd = editor.getCursorScreenPosition()
                editor.moveLeft 1

            if comDefType is "end"
                rangeEnd = editor.getCursorScreenPosition()
                editor.moveLeft 1
                while isBlockCommentDefinition_Workaround() and column isnt 0
                    editor.moveLeft 1
                    column = editor.getCursorScreenPosition().column
                editor.moveRight 1
                rangeStart = editor.getCursorScreenPosition()

            return null if column is -1

            range = editor.getSelectedScreenRange()
            range.constructor rangeStart, rangeEnd
            return range

        getApiCommentDefinitionRange = (comDefType) ->
            apiBufferRange = editor.bufferRangeForScopeAtCursor ".punctuation.definition.comment"
            return apiBufferRange if apiBufferRange?
            getApiCommentDefinitionRange_WorkAround comDefType

        getCommentDefinitionRange = (comDefType) ->
            lineCommentRange = getApiCommmentRange()
            return null if ! lineCommentRange?
            switch comDefType
                when "start"
                    lineCommentRange = lineCommentRange.start
                when "end"
                    lineCommentRange = lineCommentRange.end
                else
                    return false

            editor.setCursorScreenPosition lineCommentRange
            getApiCommentDefinitionRange comDefType

        removeBracket = () ->
            if isCursorInBlockComment()
                characterCountToTop = getCharacterCount "top"
                commentDefinitionStartRange = getCommentDefinitionRange 'start'
                while ! commentDefinitionStartRange? and characterCountToTop > 0
                    characterCountToTop--
                    editor.moveLeft 1
                    commentDefinitionStartRange = getCommentDefinitionRange 'start'
                return true if ! commentDefinitionStartRange? or characterCountToTop is 0

                characterCountToBottom = getCharacterCount "bottom"
                commentDefinitionEndRange = getCommentDefinitionRange 'end'
                while ! commentDefinitionEndRange? and characterCountToBottom > 0
                    characterCountToBottom--
                    editor.moveRight 1
                    commentDefinitionEndRange = getCommentDefinitionRange 'end'
                return true if ! commentDefinitionEndRange? or characterCountToBottom is 0

                selection = editor.getLastSelection()
                editor.transact(() ->
                    selection.setScreenRange commentDefinitionEndRange
                    selection.insertText ""
                    selection.setScreenRange commentDefinitionStartRange
                    selection.insertText ""
                )
                return true
            return false

        setBracket = () ->
            language = getLanguage();
            switch language
                when 'js'
                    commentStart = '/*'
                    commentEnd = '*/'
                when 'html'
                    commentStart = '<!--'
                    commentEnd = '-->'
                when 'coffee'
                    commentStart = '###'
                    commentEnd = '###'
                else
                    commentStart = '/*'
                    commentEnd = '*/'

            selection = editor.getLastSelection()
            rowRange = selection.getBufferRowRange()
            selection.selectLine rowRange[0]
            selection.selectLine rowRange[1]
            selection = editor.getLastSelection()
            selectionText = selection.getText()

            editor.transact(() ->
                selection.insertText(commentStart + selectionText + commentEnd, {select: false, autoIndentNewline: false})
                editor.insertNewline()
                editor.moveUp 2
                selection.joinLines()
            )

        return if removeBracket()
        setBracket()
