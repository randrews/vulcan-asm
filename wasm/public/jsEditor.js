// Editor from Serge Zaitsev, https://zserge.com/posts/js-editor/

// Syntax highlight for JS
const js = el => {
  for (const node of el.children) {
    const s = node.innerText
      .replace(/(\/\/.*)/g, '<em>$1</em>')
      .replace(
        /\b(new|if|else|do|while|switch|for|in|of|continue|break|return|typeof|function|var|const|let|\.length|\.\w+)(?=[^\w])/g,
        '<strong>$1</strong>',
      )
      .replace(/(".*?"|'.*?'|`.*?`)/g, '<strong><em>$1</em></strong>')
      .replace(/\b(\d+)/g, '<em><strong>$1</strong></em>');
    node.innerHTML = s.split('\n').join('<br/>');
  }
};

// Syntax highlight for Vulcan asm
const vulcanSyntax = el => {
  const lines = []
  for(const line of el.innerText.split('\n')) {
    const newLine = line.replace(/(;.*)/, '<em class="comment">$1</em>')
                        .replace(/([0-9a-zA-Z_]+:)/g, '<span class="label">$1</span>')
                        .replace(/(\s)(0[xb][0-9a-fA-F]+)/g, '$1<span class="number">$2</span>')
                        .replace(/(\s)(-?\d+)/g, '$1<span class="number">$2</span>')
                        .replace(/(\.org|\.db|\.equ)/g, '<span class="directive">$1</span>')
    lines.push(`<div class="line">${newLine}</div>`)
  }
  el.innerHTML = lines.join('')
}

const editor = (el, highlight = vulcanSyntax, tab = '    ') => {
  const caret = () => {
    const range = window.getSelection().getRangeAt(0);
    const prefix = range.cloneRange();
    prefix.selectNodeContents(el);
    prefix.setEnd(range.endContainer, range.endOffset);
    return prefix.toString().length;
  };

  const setCaret = (pos, parent = el) => {
    for (const node of parent.childNodes) {
      if (node.nodeType == Node.TEXT_NODE) {
        if (node.length >= pos) {
          const range = document.createRange();
          const sel = window.getSelection();
          range.setStart(node, pos);
          range.collapse(true);
          sel.removeAllRanges();
          sel.addRange(range);
          return -1;
        } else {
          pos = pos - node.length;
        }
      } else {
        pos = setCaret(pos, node);
        if (pos < 0) {
          return pos;
        }
      }
    }
    return pos;
  };

  highlight(el);

  el.addEventListener('keydown', e => {
    if (e.which === 9) {
      const pos = caret() + tab.length;
      const range = window.getSelection().getRangeAt(0);
      range.deleteContents();
      range.insertNode(document.createTextNode(tab));
      highlight(el);
      setCaret(pos);
      e.preventDefault();
    }
  });

  el.addEventListener('keyup', e => {
    if (e.keyCode >= 0x30 || e.keyCode == 0x20) {
      const pos = caret();
      highlight(el);
      setCaret(pos);
    }
    setSynced(false)
  });
};
