"""Convert helpdeco's WinHelp RTF output into Markdown.

Topics become '## title' sections with an HTML anchor per context id,
hotspot links ({\\uldb text}{\\v ctx}) become [text](#ctx), tables keep
their cells separated by ' | '.

Usage: python3 -I tools/help_to_md.py extracted/help/KAISER.rtf docs/manual.md
"""
import re
import sys


def tokenize(rtf):
    # yields ('{',), ('}',), ('ctrl', word, arg), ('text', s)
    i, n = 0, len(rtf)
    while i < n:
        c = rtf[i]
        if c == '{' or c == '}':
            yield (c,)
            i += 1
        elif c == '\\':
            nxt = rtf[i + 1]
            if nxt == "'":
                yield ('text', bytes([int(rtf[i + 2:i + 4], 16)]).decode('cp1252'))
                i += 4
            elif nxt in '\\{}':
                yield ('text', nxt)
                i += 2
            elif nxt.isalpha():
                m = re.compile(r'([a-z]+)(-?\d+)? ?').match(rtf, i + 1)
                yield ('ctrl', m.group(1), m.group(2))
                i = m.end()
            else:
                # control symbols like \~ \- \_ ; treat \~ as space, drop the rest
                if nxt == '~':
                    yield ('text', ' ')
                i += 2
        elif c in '\r\n':
            i += 1
        else:
            j = i
            while j < n and rtf[j] not in '{}\\\r\n':
                j += 1
            yield ('text', rtf[i:j])
            i = j


class Converter:
    def __init__(self):
        self.out = []          # finished markdown chunks
        self.line = []         # current paragraph text pieces
        self.link_start = None # index into self.line where a hotspot began
        self.topic = {}        # footnotes of the current topic: '$', '#', 'K'

    def text(self, s):
        self.line.append(s)

    def par(self):
        # a hotspot opened right before \par continues on the next line
        carry = self.link_start is not None and not ''.join(self.line[self.link_start:]).strip()
        if carry:
            del self.line[self.link_start:]
        self.out.append(''.join(self.line).rstrip() + '\n')
        self.line = []
        self.link_start = 0 if carry else None

    def start_link(self):
        if self.link_start is None:
            self.link_start = len(self.line)

    def end_link(self, target):
        target = target.split('>')[0].split('@')[0].strip()
        if self.link_start is not None:
            label = ''.join(self.line[self.link_start:]).strip()
            del self.line[self.link_start:]
            if label:
                self.line.append(f'[{label}](#{anchor(target)})')
        self.link_start = None

    def footnote(self, mark, value):
        value = value.strip()
        if mark == '#':
            self.topic.setdefault('#', []).append(value)
        elif mark in '$K':
            self.topic[mark] = value

    def flush_topic_header(self):
        # emitted lazily, right before the topic's first body text
        if not self.topic:
            return
        hdr = []
        for ctx in self.topic.get('#', []):
            hdr.append(f'<a id="{anchor(ctx)}"></a>')
        if '$' in self.topic:
            hdr.append(f'\n## {self.topic["$"]}\n')
        if 'K' in self.topic:
            hdr.append(f'*Stichworte: {self.topic["K"].replace(";", ", ")}*\n')
        self.out.append('\n'.join(hdr) + '\n')
        self.topic = {}


def anchor(ctx):
    return re.sub(r'[^A-Za-z0-9_-]', '_', ctx).lower()


def collect_group_text(tokens):
    """Consume tokens until the matching '}' and return the plain text."""
    depth, buf = 1, []
    for tok in tokens:
        if tok[0] == '{':
            depth += 1
        elif tok[0] == '}':
            depth -= 1
            if depth == 0:
                break
        elif tok[0] == 'text':
            buf.append(tok[1])
    return ''.join(buf)


def convert(rtf):
    conv = Converter()
    tokens = tokenize(rtf)
    pending_up = None  # last {\up X} mark, used to classify the following footnote
    for tok in tokens:
        kind = tok[0]
        if kind == '{':
            peek = next(tokens, None)
            if peek is None:
                break
            if peek[0] == 'ctrl' and peek[1] in ('fonttbl', 'colortbl', 'stylesheet'):
                collect_group_text(tokens)
            elif peek[0] == 'ctrl' and peek[1] == 'up':
                pending_up = collect_group_text(tokens).strip()
            elif peek[0] == 'ctrl' and peek[1] == 'footnote':
                body = collect_group_text(tokens)
                # footnote text starts with the repeated mark ({\up $} inside)
                mark = pending_up or body[:1]
                if body.startswith(mark):
                    body = body[len(mark):]
                conv.footnote(mark, body)
                pending_up = None
            elif peek[0] == 'ctrl' and peek[1] == 'v':
                conv.end_link(collect_group_text(tokens))
            elif peek[0] == 'text':
                conv.flush_topic_header()
                conv.text(peek[1])
        elif kind == 'text':
            if tok[1].strip():
                conv.flush_topic_header()
            conv.text(tok[1])
        elif kind == 'ctrl':
            word = tok[1]
            if word == 'par':
                conv.par()
            elif word == 'page':
                conv.par()
                conv.out.append('\n---\n')
            elif word == 'cell':
                conv.text(' | ')
            elif word == 'row':
                conv.par()
            elif word == 'tab':
                conv.text('\t')
            elif word in ('uldb', 'ul', 'strike'):
                conv.start_link()
    conv.par()
    md = ''.join(conv.out)
    md = re.sub(r'\n{3,}', '\n\n', md)
    return md


def main():
    src, dst = sys.argv[1], sys.argv[2]
    rtf = open(src, 'rb').read().decode('latin-1')  # \'xx escapes carry the real cp1252 bytes
    md = convert(rtf)
    header = '# Kaiser v1.23 – Handbuch (aus KAISER.HLP)\n\nAutomatisch erzeugt von tools/help_to_md.py.\n\n'
    open(dst, 'w', encoding='utf-8').write(header + md)


if __name__ == '__main__':
    main()
