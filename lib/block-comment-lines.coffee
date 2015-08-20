module.exports =
    activate: ->
        atom.commands.add 'atom-workspace', 'block-comment-lines:toggle': @toggle
        # atom.workspaceView.command "block-comment-line:toggle", => @toggle()

    toggle: ->
        workspace = atom.workspace
        editor = workspace.getActiveTextEditor()
        selection = editor.getLastSelection()

        isBlockCommentDefinition = () ->
            descriptorArray = getDescriptorArray()
            for element in descriptorArray
                if (element.indexOf "punctuation" isnt -1) and (element.indexOf("definition") isnt -1)
                    return true
            return false

        isEmbeddedLanguage = () ->
            descriptorArray = getDescriptorArray()
            for element in descriptorArray
                if (element.indexOf("embedded") > -1)
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

        getBufferRangeForScopeAtCursorWorkAround = (sort) ->
            column = -1
            # editor.insertText("#{column}", {select: true})

            if sort is "start"
                columnWidth = getColumnWidth()
                rangeStart = editor.getCursorScreenPosition()
                editor.moveRight 1
                while isBlockCommentDefinition() and column isnt columnWidth
                    editor.moveRight 1
                    column = editor.getCursorScreenPosition().column
                rangeEnd = editor.getCursorScreenPosition()
                editor.moveLeft 1

            if sort is "end"
                rangeEnd = editor.getCursorScreenPosition()
                editor.moveLeft 1
                while isBlockCommentDefinition() and column isnt 0
                    editor.moveLeft 1
                    column = editor.getCursorScreenPosition().column
                rangeStart = editor.getCursorScreenPosition()
                editor.moveRight 1

            return null if column is -1

            range = editor.getSelectedScreenRange()
            range.constructor rangeStart, rangeEnd
            return range

        getCommentDefinitionRange = (sort) ->
            switch sort
                when "start"
                    lineCommentRange = editor.bufferRangeForScopeAtCursor(".comment.block").start
                when "end"
                    lineCommentRange = editor.bufferRangeForScopeAtCursor(".comment.block").end
                else
                    return false

            editor.setCursorScreenPosition(lineCommentRange)
            ### workAround for "bufferRangeForScopeAtCursor" ###
            if isEmbeddedLanguage()
                getBufferRangeForScopeAtCursorWorkAround(sort)
            else
                editor.bufferRangeForScopeAtCursor(".punctuation.definition.comment")

        isCursorInBlockComment = () ->
            editor.bufferRangeForScopeAtCursor(".comment.block")?

        isCurcorInBlockCommentDefinition = () ->
            editor.bufferRangeForScopeAtCursor(".punctuation.definition.comment")?

        removeBracket = () ->
            if isCursorInBlockComment()
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
