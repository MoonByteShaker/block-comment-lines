module.exports =
    activate: ->
        atom.commands.add 'atom-workspace', 'block-comment-lines:toggle': @toggle
        # atom.workspaceView.command "block-comment-line:toggle", => @toggle()

    toggle: ->
        workspace = atom.workspace
        editor = workspace.getActiveTextEditor()
        selection = editor.getLastSelection()

        isBlockCommentDefinition_Workaround = () ->
            return true if isCurcorInBlockCommentDefinition()
            descriptorArray = getDescriptorArray()
            for element in descriptorArray
                if element.indexOf("punctuation") isnt -1 and element.indexOf("definition") isnt -1
                    return true
            return false

        getDescriptorArray = () ->
            descriptorArray = editor.scopeDescriptorForBufferPosition(editor.getCursorBufferPosition()).getScopesArray()

        getColumnWidth = () ->
            oldCursorPos = editor.getSelectedScreenRange()
            editor.moveToEndOfScreenLine()
            columnWidth = editor.getSelectedScreenRange().end.serialize()[1]
            editor.setSelectedScreenRange(oldCursorPos)
            return columnWidth

        isCursorInBlockComment_WorkAround = () ->
            return true if isCursorInBlockComment()
            descriptorArray = getDescriptorArray()
            for element in descriptorArray
                if element.indexOf("comment") isnt -1 and element.indexOf("block") isnt -1 and element.indexOf("definition") is -1
                    return true
            return false

        getBufferRangeForCommentScope_WorkAround = () ->
            apiBufferRange = editor.bufferRangeForScopeAtCursor(".comment.block")
            return apiBufferRange if apiBufferRange?
            oldCursorPos = editor.getCursorScreenPosition()

            editor.moveToBeginningOfLine()
            columnWidth = getColumnWidth()
            column = -1

            isStartOfBlockComment = isCursorInBlockComment()
            while (! isStartOfBlockComment) and column < columnWidth
                editor.moveRight 1
                isStartOfBlockComment = isCursorInBlockComment()
                column = editor.getCursorScreenPosition().column

            if ! isStartOfBlockComment
                editor.setCursorScreenPosition(oldCursorPos)
                return null

            apiBufferRange = editor.bufferRangeForScopeAtCursor(".comment.block")
            return apiBufferRange

        getBufferRangeForScopeAtCursorWorkAround = (sort) ->
            apiBufferRange = editor.bufferRangeForScopeAtCursor(".punctuation.definition.comment")
            return apiBufferRange if apiBufferRange?
            column = -1
            # editor.insertText("#{column}", {select: true})

            if sort is "start"
                columnWidth = getColumnWidth()
                rangeStart = editor.getCursorScreenPosition()
                editor.moveRight 1
                while isBlockCommentDefinition_Workaround() and column isnt columnWidth
                    editor.moveRight 1
                    column = editor.getCursorScreenPosition().column
                rangeEnd = editor.getCursorScreenPosition()
                editor.moveLeft 1

            if sort is "end"
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

        getCommentDefinitionRange = (sort) ->
            lineCommentRange = getBufferRangeForCommentScope_WorkAround()
            return null if ! lineCommentRange?
            switch sort
                when "start"
                    lineCommentRange = lineCommentRange.start
                when "end"
                    lineCommentRange = lineCommentRange.end
                else
                    return false

            editor.setCursorScreenPosition(lineCommentRange)
            getBufferRangeForScopeAtCursorWorkAround(sort)

        isCursorInBlockComment = () ->
            editor.bufferRangeForScopeAtCursor(".comment.block")?

        isCurcorInBlockCommentDefinition = () ->
            editor.bufferRangeForScopeAtCursor(".punctuation.definition.comment")?

        removeBracket = () ->
            if isCursorInBlockComment_WorkAround()
                commentDefinitionStartRange = getCommentDefinitionRange('start')
                while ! commentDefinitionStartRange?
                    editor.moveLeft(1)
                    commentDefinitionStartRange = getCommentDefinitionRange('start')

                commentDefinitionEndRange = getCommentDefinitionRange('end')
                while ! commentDefinitionEndRange?
                    editor.moveRight(1)
                    commentDefinitionEndRange = getCommentDefinitionRange('end')

                if ! commentDefinitionStartRange? or ! commentDefinitionEndRange?
                    return true

                editor.transact(() ->
                    selection.setScreenRange(commentDefinitionEndRange)
                    selection.insertText("")
                    selection.setScreenRange(commentDefinitionStartRange)
                    selection.insertText("")
                )
                return true
            return false

        getLanguage = () ->
            descriptorArray = getDescriptorArray()
            if descriptorArray.length > 1 and descriptorArray[1].match(/embedded/g)
                descriptorArray = descriptorArray[1].split "."
            else
                descriptorArray = descriptorArray[0].split "."
            return descriptorArray[1]

        return if removeBracket()

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
        selection.selectLine(rowRange[0]);
        selection.selectLine(rowRange[1]);
        selection = editor.getLastSelection()
        selectionText = selection.getText()

        editor.transact(() ->
            selection.insertText(commentStart + selectionText + commentEnd, {select: false, autoIndentNewline: false})
            editor.insertNewline()
            editor.moveUp(2)
            selection.joinLines()
        )
