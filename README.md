# block-comment-lines package
Puts selected lines in a block-comment or removes it by toggling. To remove the comment just place cursor inside comment.
Besides document language this package also identifies embedded languages.
The default block comment definition for languages not yet supported is /\*....\*/.
Supported languages are:
- JavaScript
- HTML
- CSS
- CoffeeScript
- Java
- C, C++, C#
- PHP
- Markdown
- ActionScript
- TypeScript

# Default keybinding:

The default keybinding to toggle the block-comment-lines is `alt-shift-B`.

You can override it by copy-pasting the following code section and replacing the `alt-shift-b` with your prefered keybinding.
```
'atom-text-editor':
  'alt-shift-B': 'block-comment-lines:toggle'
```

![presentation_1](https://raw.githubusercontent.com/kaasbaardje/block-comment-lines/master/gifs/presentation_1.gif)

Todo:
- second shortcurt for documentation block-comment --> /\*\*....\*/
- adjustable text for start and end of block-comments like: ### --> /\*### .... ###\*/
- option for adjustable background-colors in block-comments
- option for enumeration in block-comments
