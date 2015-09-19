module.exports =
    activate: ->
        atom.commands.add 'atom-workspace', 'block-comment-lines:toggle': @toggle
        atom.commands.add 'atom-workspace', 'block-comment-lines:toggleWithConfigText': @toggleWithConfigText
    config:
      commentText:
        type: 'string'
        default: '###'
    toggle: ->
        methods = module.exports.methods
        methods.setEditor()
        return if methods.removeBracket()
        methods.setBracket()
    toggleWithConfigText: ->
        methods = module.exports.methods
        methods.setEditor()
        configText = atom.config.get('block-comment-lines.commentText')
        configText = "/*" + configText + "*/"
        return if methods.removeBracket(configText)
        methods.setBracket(configText)
    methods:
        setBracket: (configText) ->
            editor = @editor
            language = @getLanguage()
            switch language
                when 'js'
                    commentStart = '/*'
                    commentEnd = '*/'
                when 'html', 'gfm'
                    commentStart = '<!--'
                    commentEnd = '-->'
                when 'coffee'
                    commentStart = '###'
                    commentEnd = '###'
                when 'sh', 'shell'
                    commentStart = ": <<'COMMENT'"
                    commentEnd = 'COMMENT'
                else
                    commentStart = '/*'
                    commentEnd = '*/'

            selection = editor.getLastSelection()

            isWrapped = editor.isSoftWrapped()
            editor.setSoftWrapped(false) if isWrapped

            rowRange = selection.getBufferRowRange()
            selectionEnd = editor.getSoftWrapColumn()
            editor.setCursorScreenPosition([rowRange[0],0])
            editor.selectToFirstCharacterOfLine()
            selectionStart = editor.getSelectedScreenRange().end.column
            screenRange = [
                [rowRange[0], selectionStart],
                [rowRange[1], selectionEnd]]
            editor.setSelectedScreenRange(screenRange)
            selectionText = selection.getText()

            @editor.transact ->
                if configText
                    editor.insertText("#{configText}")
                    editor.insertNewline()
                selection.insertText(commentStart + selectionText + commentEnd, {select: false, autoIndentNewline: false})
                if configText
                    editor.insertNewline()
                    editor.setCursorScreenPosition([rowRange[1]+2,selectionStart])
                    editor.insertText("#{configText}")

            editor.setSoftWrapped(true) if isWrapped
        removeBracket: (configText) ->
            if @isCursorInBlockComment()
                @editor.toggleSoftWrapped()
                characterCountToTop = @getCharacterCount "top"
                commentDefinitionStartRange = @getCommentDefinitionRange 'start'
                while ! commentDefinitionStartRange? and characterCountToTop > 0
                    characterCountToTop--
                    @editor.moveLeft 1
                    commentDefinitionStartRange = @getCommentDefinitionRange 'start'
                if ! commentDefinitionStartRange? or characterCountToTop is 0
                    @editor.toggleSoftWrapped()
                    return true

                characterCountToBottom = @getCharacterCount "bottom"
                commentDefinitionEndRange = @getCommentDefinitionRange 'end'
                while ! commentDefinitionEndRange? and characterCountToBottom > 0
                    characterCountToBottom--
                    @editor.moveRight 1
                    commentDefinitionEndRange = @getCommentDefinitionRange 'end'
                if ! commentDefinitionEndRange? or characterCountToBottom is 0
                    @editor.toggleSoftWrapped()
                    return true

                # if configText
                #     commentDefinitionStartRange = [
                #         [commentDefinitionStartRange.start.row-1,
                #         commentDefinitionStartRange.start.column],
                #         commentDefinitionStartRange.end]
                #     commentDefinitionEndRange = [
                #         commentDefinitionEndRange.start,
                #         [commentDefinitionEndRange.end.row+1,
                #         commentDefinitionEndRange.end.column]]

                selection = @editor.getLastSelection()
                @editor.transact ->
                    selection.setScreenRange commentDefinitionEndRange
                    selection.insertText ""
                    selection.setScreenRange commentDefinitionStartRange
                    selection.insertText ""

                @editor.toggleSoftWrapped()
                return true
            return false
        setEditor: ->
            @editor = atom.workspace.getActiveTextEditor()
        editor: null
        getDescriptorArray: ->
            descriptorArray = @editor.scopeDescriptorForBufferPosition(@editor.getCursorBufferPosition()).getScopesArray()
        getColumnWidth: ->
            oldCursorPos = @editor.getCursorScreenPosition()
            @editor.moveToEndOfScreenLine()
            columnWidth = @editor.getSelectedScreenRange().end.serialize()[1]
            @editor.setCursorScreenPosition oldCursorPos
            return columnWidth
        getCharacterCount: (countDirection) ->
            startPos = @editor.getCursorScreenPosition()
            buffer = @editor.getBuffer()

            if countDirection is "bottom"
                lineCount = @editor.getScreenLineCount() - startPos.row
                endPos = buffer.getEndPosition()
            else
                lineCount = startPos.row
                endPos = buffer.getFirstPosition()

            range = @editor.getSelectedScreenRange()
            range.constructor startPos, endPos
            bufferText = buffer.getTextInRange(range)
            characterCount = bufferText.split(/./).length + lineCount
            @editor.setCursorScreenPosition startPos
            return characterCount
        getLanguage: ->
            descriptorArray = @getDescriptorArray()
            if descriptorArray.length > 1 and descriptorArray[1].match /embedded/g
                descriptorArray = descriptorArray[1].split "."
            else
                descriptorArray = descriptorArray[0].split "."
            return descriptorArray[1]
        isBlockCommentDefinition_Workaround: ->
            descriptorArray = @getDescriptorArray()
            for element in descriptorArray
                if element.indexOf("punctuation") isnt -1 and element.indexOf("definition") isnt -1
                    return true
            return false
        isCurcorInBlockCommentDefinition: ->
            return true if @editor.bufferRangeForScopeAtCursor(".punctuation.definition.comment")?
            @isBlockCommentDefinition_Workaround()
        isCursorInBlockComment_WorkAround: ->
            descriptorArray = @getDescriptorArray()
            for element in descriptorArray
                if element.indexOf("comment") isnt -1 and element.indexOf("block") isnt -1 and element.indexOf("definition") is -1
                    return true
            return false
        isCursorInBlockComment: ->
            return true if @editor.bufferRangeForScopeAtCursor(".comment.block")?
            @isCursorInBlockComment_WorkAround()
        getApiCommmentRange_WorkAround: ->
            return null if ! @isCursorInBlockComment_WorkAround()
            oldCursorPos = @editor.getCursorScreenPosition()
            @editor.moveToBeginningOfLine()
            columnWidth = @getColumnWidth()
            column = -1

            isStartOfBlockComment = @editor.bufferRangeForScopeAtCursor(".comment.block")?
            while (! isStartOfBlockComment) and column < columnWidth
                @editor.moveRight 1
                isStartOfBlockComment = @editor.bufferRangeForScopeAtCursor(".comment.block")?
                column = @editor.getCursorScreenPosition().column

            if ! isStartOfBlockComment
                @editor.setCursorScreenPosition oldCursorPos
                return null

            apiBufferRange = @editor.bufferRangeForScopeAtCursor ".comment.block"
            return apiBufferRange
        getApiCommmentRange: ->
            apiBufferRange = @editor.bufferRangeForScopeAtCursor ".comment.block"
            return apiBufferRange if apiBufferRange?
            @getApiCommmentRange_WorkAround()
        getApiCommentDefinitionRange_WorkAround: (comDefType) ->
            return null if ! @isBlockCommentDefinition_Workaround()
            column = -1

            if comDefType is "start"
                columnWidth = @getColumnWidth()
                rangeStart = @editor.getCursorScreenPosition()
                @editor.moveRight 1
                while @isBlockCommentDefinition_Workaround() and column < columnWidth
                    @editor.moveRight 1
                    column = @editor.getCursorScreenPosition().column
                rangeEnd = @editor.getCursorScreenPosition()
                @editor.moveLeft 1

            if comDefType is "end"
                rangeEnd = @editor.getCursorScreenPosition()
                @editor.moveLeft 1
                while @isBlockCommentDefinition_Workaround() and column isnt 0
                    @editor.moveLeft 1
                    column = @editor.getCursorScreenPosition().column
                @editor.moveRight 1
                rangeStart = @editor.getCursorScreenPosition()

            return null if column is -1

            range = @editor.getSelectedScreenRange()
            range.constructor rangeStart, rangeEnd
            return range
        getApiCommentDefinitionRange: (comDefType) ->
            apiBufferRange = @editor.bufferRangeForScopeAtCursor ".punctuation.definition.comment"
            return apiBufferRange if apiBufferRange?
            @getApiCommentDefinitionRange_WorkAround comDefType
        getCommentDefinitionRange: (comDefType) ->
            lineCommentRange = @getApiCommmentRange()
            return null if ! lineCommentRange?
            switch comDefType
                when "start"
                    lineCommentRange = lineCommentRange.start
                when "end"
                    lineCommentRange = lineCommentRange.end
                else
                    return false
            @editor.setCursorScreenPosition lineCommentRange
            @getApiCommentDefinitionRange comDefType
