namespace Jsona {
  enum TokenType {
    BEGIN_OBJECT,
    END_OBJECT,
    BEGIN_ARRAY,
    END_ARRAY,
    NULL,
    NUMBER,
    STRING,
    BOOLEAN,
    SEP_COLON,
    SEP_COMMA,
    END_DOCUMENT,
    ERROR
  }

  class Token {
    private TokenType tokenType;
    private string value;
    Token(TokenType tokenType = NULL, string value = "") {
      this.tokenType = tokenType;
      this.value = value;
    }

    TokenType getType() {
      return tokenType;
    }

    string getValue() {
      return value;
    }
  }

  class Tokenizer {
    private uint pos = 0;
    private uint line = 1;
    private uint col = 1;
    private string dataStr = "";
    private char buffer = "";
    private bool shouldConvertEscape = true;
    private array < string > endingCharStandard = {
      "\""
    };
    private array < string > endingCharNonStandard = {
      ":"
    };
    private array < Token @ > tokens;

    Tokenizer(bool shouldConvertEscape = true) {
      this.shouldConvertEscape = shouldConvertEscape;
    }

    array < Token @ > parse(string str) {
      dataStr = str;
      tokenize();
      return tokens;
    }

    array < Token @ > parse(string str, bool shouldConvertEscape) {
      this.shouldConvertEscape = shouldConvertEscape;
      parse(str);
      return tokens;
    }

    private void tokenize() {
      Token @ currentToken;
      tokens.resize(0);
      pos = 0;
      line = 0;
      do {
        @currentToken = process();
        tokens.insertLast(@currentToken);
      } while (currentToken.getType() != END_DOCUMENT && currentToken.getType() != ERROR);
      if (currentToken.getType() == ERROR) {
        g_Game.AlertMessage(at_console, "[ERROR::Tokenizer] An error occurred while trying to tokenize JSON string " + currentToken.getValue() + "\n");
      }
    }

    private char getNextChar() {
      buffer = dataStr.SubString(pos, 1);
      if (pos < dataStr.Length()) {
        pos++;
      }
      if (buffer == "\n") {
        line++;
        col = 1;
      } else {
        col++;
      }
      return buffer;
    }

    private char peekChar(int offset = 0) {
      uint relativePos = pos + offset;
      if (relativePos > 0 && relativePos < dataStr.Length()) {
        return dataStr.SubString(relativePos, 1);
      } else {
        return buffer;
      }
    }

    private Token process() {
      while (true) {
        if (pos >= dataStr.Length()) {
          return Token(END_DOCUMENT, "");
        }
        getNextChar();
        if (!isspace(buffer)) {
          break;
        }
      }
      if (buffer == "{") {
        return Token(BEGIN_OBJECT, buffer);
      } else if (buffer == "}") {
        return Token(END_OBJECT, buffer);
      } else if (buffer == "[") {
        return Token(BEGIN_ARRAY, buffer);
      } else if (buffer == "]") {
        return Token(END_ARRAY, buffer);
      } else if (buffer == ",") {
        return Token(SEP_COMMA, buffer);
      } else if (buffer == ":") {
        return Token(SEP_COLON, buffer);
      } else if (buffer == "n") {
        return readNull();
      } else if (buffer == "t") {
        return readBoolean(true);
      } else if (buffer == "f") {
        return readBoolean(false);
      } else if (buffer == "\"") {
        return readString(true);
      } else if (buffer == "-" || isdigit(buffer)) {
        return readNumber();
      } else {
        // ??????????????? key-value
        if (isalpha(buffer)) {
          return readString(false);
        }
        return Token(NULL, "");
      }
    }

    private Token readNull() {
      if (!(getNextChar() == "u" && getNextChar() == "l" && getNextChar() == "l")) {
        // ???????????? null????????????????????? key-value????????? string ?????????????????? : ??????????????????????????????
        pos -= 3;
        return readString(false);
      } else {
        return Token(NULL, "");
      }
    }

    private Token readBoolean(bool expected) {
      string tmp;
      if (expected) {
        tmp = "t";
        for (uint i = 0; i < 3; i++) {
          tmp += getNextChar();
        }
      } else {
        tmp = "f";
        for (uint i = 0; i < 4; i++) {
          tmp += getNextChar();
        }
      }
      if (expected) {
        if (tmp == "true") {
          return Token(BOOLEAN, "true");
        } else {
          // ???????????? true????????????????????? key-value????????? string ??????
          pos -= 3;
          return readString(false);
        }
      } else {
        if (tmp == "false") {
          return Token(BOOLEAN, "false");
        } else {
          // ???????????? false????????????????????? key-value????????? string ??????
          pos -= 4;
          return readString(false);
        }
      }
    }

    private Token readString(bool isStandard) {
      array < string > endingChar;
      string strStorage;
      if (isStandard) { // ?????? / ????????? ????????????????????????????????????
        strStorage = "";
      } else {
        strStorage = peekChar(-1); // ?????????????????? buffer ?????????????????????
      }

      int initLine = line;
      int initCol = col;
      while (true) {
        string next = getNextChar();
        if (!isStandard && isspace(buffer)) { // ?????????????????????????????????
          continue;
        }
        if (pos < dataStr.Length()) {
          bool shouldEnd = false;
          bool isEndTypeStandard = isStandard;
          for (uint i = 0; i < endingCharStandard.length(); i++) {
            if (endingCharStandard[i] == buffer) {
              shouldEnd = true;
              isEndTypeStandard = true;
            }
          }
          for (uint i = 0; i < endingCharNonStandard.length(); i++) {
            if (endingCharNonStandard[i] == buffer) {
              shouldEnd = true;
              isEndTypeStandard = false;
            }
          }
          if (!shouldEnd) {
            if (buffer == "\\" && shouldConvertEscape) { // ??????????????????
              strStorage += convertEscape(isStandard);
            } else {
              strStorage += buffer;
            }
          } else {
            if (isEndTypeStandard != isStandard) { // ?????????????????????????????????????????????????????????????????????
              return Token(ERROR, "(" + initLine + ", " + initCol + "): unexpected end of string");
            }
            if (!isStandard) {
              pos--;
            }
            break;
          }
        } else { // ???????????????????????????????????????????????????
          return Token(ERROR, "(" + initLine + ", " + initCol + "): no end of string");
        }
      }
      return Token(STRING, strStorage);
    }

    private string convertEscape(bool isStandard) {
      string storageStr = "";
      char next = getNextChar();
      // BUG: Following escape characters are currently not available in AngelScript: \f \b
      if (next == "\"") {
        return "\"";
      } else if (next == "\'") {
        return "\'";
      } else if (next == "\\") {
        return "\\";
      } else if (next == "n") {
        return "\n";
      } else if (next == "r") {
        return "\r";
      } else if (next == "t") {
        return "\t";
      } else if (next == "/") {
        return "/";
      }
      if (next == "u") {
        storageStr = "\\u";
        while (true) {
          getNextChar();
          if (pos < dataStr.Length() - 1) {
            bool shouldEnd = false;
            for (uint i = 0; i < endingCharStandard.length(); i++) {
              if (endingCharStandard[i] == buffer) {
                shouldEnd = true;
              }
            }
            for (uint i = 0; i < endingCharNonStandard.length(); i++) {
              if (endingCharNonStandard[i] == buffer) {
                shouldEnd = true;
              }
            }
            if (shouldEnd) { // ??????????????????????????????
              pos--; // ?????? getString ??????
              return storageStr;
            }
            storageStr += buffer;
            if (storageStr.Length() >= 6) {
              // BUG: storageStr here is already an escape character, but cannot be converted to a unicode character. This is due to the limitation of AngelScript.
              return storageStr;
            }
          } else {
            storageStr += buffer;
            return storageStr;
          }
        }
      }
      // ???????????????????????????????????????????????????????????????????????????
      pos--;
      return "\\";
    }
    private Token readNumber() {
      string num = buffer;
      while (true) {
        char next = getNextChar();
        if (pos < dataStr.Length()) {
          if (isdigit(next) || next == ".") {
            num += next;
          } else {
            pos--;
            break;
          }
        } else {
          break;
        }
      }
      return Token(NUMBER, num);
    }
  }
}