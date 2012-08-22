var BrowserEmu, DelegateInstruction, Instruction, InterpretedInstruction, InterpretedProcessor, Interpreter, Processor, Processor4917, State, Symbol, SyntaxError, Token, Tokeniser, WorkerEmu, board, messageListener,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; },
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

Instruction = (function() {

  function Instruction(description, ipIncrement) {
    this.description = description;
    this.ipIncrement = ipIncrement;
  }

  Instruction.prototype.execute = function(state) {};

  return Instruction;

})();

Processor = (function() {

  function Processor(name, changeHandler) {
    var exec, fetch, inc;
    this.name = name;
    this.memoryBitSize = 4;
    this.registerBitSize = 4;
    this.numMemoryAddresses = 16;
    this.instructions = [];
    this.setRegisterNames(['IP', 'IS']);
    this.state = new State(this, changeHandler);
    fetch = function(state) {
      var instruction;
      instruction = state.getMemory(state.getRegister('IP'));
      return state.setRegister('IS', instruction);
    };
    inc = function(state) {
      var instruction, instructionNum, ip, ipIncrement;
      ip = state.getRegister('IP');
      instructionNum = state.getRegister('IS');
      instruction = null;
      if (instructionNum < state.processor.instructions.length) {
        instruction = state.processor.instructions[instructionNum];
      }
      ipIncrement = 1;
      if (instruction) {
        ipIncrement = instruction.ipIncrement;
      }
      return state.setRegister('IP', ip + ipIncrement);
    };
    exec = function(state) {
      var instruction, instructionNum;
      instructionNum = state.getRegister('IS');
      instruction = null;
      if (instructionNum < state.processor.instructions.length) {
        instruction = state.processor.instructions[instructionNum];
      }
      if (instruction) {
        return instruction.execute(state);
      }
    };
    this.pipeline = [fetch, inc, exec];
  }

  Processor.prototype.step = function() {
    if (this.state.isHalted) {
      return;
    }
    this.pipeline[this.state.pipelineStep](this.state);
    return this.state.nextStep(this.pipeline.length);
  };

  Processor.prototype.run = function(maxCycles) {
    var cycle, maxSteps, _results;
    cycle = 0;
    maxSteps = maxCycles * this.state.processor.pipeline.length;
    _results = [];
    while ((cycle < maxSteps) && !this.state.isHalted) {
      this.step();
      _results.push(cycle += 1);
    }
    return _results;
  };

  Processor.prototype.setRegisterNames = function(names) {
    var hasIP, hasIS, i, name, _i, _ref;
    this.registerIndexLookup = {};
    this.registerNames = names;
    this.numRegisters = names.length;
    hasIS = false;
    hasIP = false;
    for (i = _i = 0, _ref = this.numRegisters; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
      name = names[i];
      this.registerIndexLookup[name] = i;
      if (name === 'IP') {
        hasIP = true;
      }
      if (name === 'IS') {
        hasIS = true;
      }
    }
    if (!(hasIS && hasIP)) {
      throw new Error("Processor must have both IP and IS registers");
    }
  };

  return Processor;

})();

State = (function() {

  function State(processor, changeHandler) {
    this.processor = processor;
    this.changeHandler = changeHandler;
    this.reset();
    if (!this.changeHandler) {
      this.changeHandler = function(event) {
        if (console.log) {
          return console.log(event);
        }
      };
    }
  }

  State.prototype.eventFor = function() {
    var args;
    args = Array.prototype.slice.call(arguments);
    return {
      state: this.toObject(),
      action: args[0],
      "arguments": args.slice(1)
    };
  };

  State.prototype.reset = function() {
    var i, _i, _j, _ref, _ref1;
    this.memory = [];
    this.registers = [];
    for (i = _i = 0, _ref = this.processor.numMemoryAddresses; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
      this.memory.push(0);
    }
    for (i = _j = 0, _ref1 = this.processor.numRegisters; 0 <= _ref1 ? _j < _ref1 : _j > _ref1; i = 0 <= _ref1 ? ++_j : --_j) {
      this.registers.push(0);
    }
    this.isHalted = false;
    this.output = "";
    this.numBellRings = 0;
    this.pipelineStep = 0;
    this.executionStep = 0;
    return this.changeHandler(this.eventFor('reset'));
  };

  State.prototype.constrainRegister = function(value) {
    var mask;
    mask = (1 << this.processor.registerBitSize) - 1;
    return value & mask;
  };

  State.prototype.constrainMemory = function(value) {
    var mask;
    mask = (1 << this.processor.memoryBitSize) - 1;
    return value & mask;
  };

  State.prototype.constrainAddress = function(value) {
    var newValue;
    newValue = value % this.processor.numMemoryAddresses;
    if (newValue < 0) {
      newValue += this.processor.numMemoryAddresses;
    }
    return newValue;
  };

  State.prototype.getRegister = function(registerName) {
    var registerIndex;
    registerIndex = this.processor.registerIndexLookup[registerName];
    return this.constrainRegister(this.registers[registerIndex]);
  };

  State.prototype.setRegister = function(registerName, value) {
    var newValue, registerIndex;
    registerIndex = this.processor.registerIndexLookup[registerName];
    newValue = this.constrainRegister(value);
    this.registers[registerIndex] = newValue;
    return this.changeHandler(this.eventFor('setRegister', registerName, newValue));
  };

  State.prototype.getMemory = function(address) {
    address = this.constrainAddress(address);
    return this.memory[address];
  };

  State.prototype.setMemory = function(address, value) {
    var newValue;
    address = this.constrainAddress(address);
    newValue = this.constrainMemory(value);
    this.memory[address] = newValue;
    return this.changeHandler(this.eventFor('setMemory', address, newValue));
  };

  State.prototype.getAllMemory = function() {
    return this.memory.slice();
  };

  State.prototype.setAllMemory = function(values) {
    var i, _i, _ref;
    for (i = _i = 0, _ref = this.processor.numMemoryAddresses; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
      if (i < values.length) {
        this.memory[i] = this.constrainMemory(values[i]);
      } else {
        this.memory[i] = 0;
      }
    }
    return this.changeHandler(this.eventFor('setAllMemory', values));
  };

  State.prototype.setAllRegisters = function(values) {
    var i, _i, _ref;
    for (i = _i = 0, _ref = this.processor.numRegisters; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
      if (i < values.length) {
        this.registers[i] = this.constrainRegisters(values[i]);
      } else {
        this.registers[i] = 0;
      }
    }
    return this.changeHandler(this.eventFor('setAllRegisters', values));
  };

  State.prototype.nextStep = function(pipelineLength) {
    this.pipelineStep = (this.pipelineStep + 1) % pipelineLength;
    if (this.pipelineStep === 0) {
      this.executionStep += 1;
    }
    return this.changeHandler(this.eventFor('nextStep', this.pipelineStep, this.executionStep));
  };

  State.prototype.print = function(value) {
    this.output += value + " ";
    return this.changeHandler(this.eventFor('print', value));
  };

  State.prototype.printASCII = function(value) {
    this.output += String.fromCharCode(value);
    return this.changeHandler(this.eventFor('printASCII', value));
  };

  State.prototype.ringBell = function() {
    this.numBellRings += 1;
    return this.changeHandler(this.eventFor('ringBell'));
  };

  State.prototype.halt = function() {
    this.isHalted = true;
    return this.changeHandler(this.eventFor('halt'));
  };

  State.prototype.duplicate = function() {
    var newState;
    newState = new State(processor);
    newState.fromObject(this.toObject());
    return newState;
  };

  State.prototype.fromObject = function(state) {
    this.setAllMemory(state.memory);
    this.setAllRegisters(state.registers);
    this.isHalted = state.isHalted;
    this.output = state.output;
    this.numBellRings = state.numBellRings;
    this.pipelineStep = state.pipelineStep;
    this.executionStep = state.executionStep;
    return this.changeHandler(this.eventFor('fromObject'));
  };

  State.prototype.toObject = function() {
    return {
      memory: this.memory,
      registers: this.registers,
      isHalted: this.isHalted,
      output: this.output,
      numBellRings: this.numBellRings,
      pipelineStep: this.pipelineStep,
      executionStep: this.executionStep
    };
  };

  return State;

})();

BrowserEmu = (function() {

  function BrowserEmu() {
    this.messageCallbacks = [];
    this.maxCycles = 100;
  }

  BrowserEmu.prototype.defineProcessor = function(definition) {
    var changeHandler,
      _this = this;
    changeHandler = function(event) {
      return _this.send('update', event);
    };
    return this.processor = new InterpretedProcessor(definition, changeHandler);
  };

  BrowserEmu.prototype.send = function(method, data) {
    var callback, _i, _len, _ref, _results;
    _ref = this.messageCallbacks;
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      callback = _ref[_i];
      _results.push(callback({
        data: JSON.stringify({
          method: method,
          data: data
        })
      }));
    }
    return _results;
  };

  BrowserEmu.prototype.onmessage = function(callback) {
    return this.messageCallbacks.push(callback);
  };

  BrowserEmu.prototype.postMessage = function(message) {
    var address, data, dataObject, instruction, instructions, method, name, value, _i, _len, _ref;
    try {
      dataObject = JSON.parse(message);
      method = dataObject.method;
      data = dataObject.data;
    } catch (e) {
      method = message;
      data = null;
    }
    switch (method) {
      case 'init':
        this.processor = null;
        this.defineProcessor(data);
        instructions = [];
        _ref = this.processor.instructions;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          instruction = _ref[_i];
          instructions.push({
            description: instruction.description,
            ipIncrement: instruction.ipIncrement
          });
        }
        return this.send('ready', {
          name: this.processor.name,
          memoryBitSize: this.processor.memoryBitSize,
          numMemoryAddresses: this.processor.numMemoryAddresses,
          registerBitSize: this.processor.registerBitSize,
          registerNames: this.processor.registerNames,
          registerIndexLookup: this.processor.registerIndexLookup,
          numRegisters: this.processor.numRegisters,
          instructions: instructions
        });
      case 'updateRegister':
        name = data.registerName;
        value = data.value;
        return this.processor.state.setRegister(name, value);
      case 'updateMemory':
        address = data.memoryAddress;
        value = data.value;
        return this.processor.state.setMemory(address, value);
      case 'updateState':
        return this.processor.state.fromObject(data);
      case 'reset':
        if (this.processor != null) {
          return this.processor.state.reset();
        }
        break;
      case 'step':
        if (this.processor != null) {
          return this.processor.step();
        }
        break;
      case 'run':
        if (this.processor != null) {
          this.processor.run(this.maxCycles);
          if (!this.processor.state.isHalted) {
            return this.send('report', 'Maximum number of execution cycles exceeded. Execution paused.');
          }
        }
    }
  };

  return BrowserEmu;

})();

if (!(window.document != null)) {
  board = WorkerEmu();
  messageListener = function(event) {
    var payload;
    payload = JSON.parse(event);
    return board.receive(payload.method, payload.data);
  };
  self.addEventListener('message', messageListener, false);
}

WorkerEmu = (function() {

  function WorkerEmu() {}

  WorkerEmu.prototype.receive = function(method, data) {};

  WorkerEmu.prototype.send = function(method, data) {
    var payload;
    payload = JSON.stringify({
      method: method,
      data: data
    });
    return self.postMessage(payload);
  };

  return WorkerEmu;

})();

DelegateInstruction = (function(_super) {

  __extends(DelegateInstruction, _super);

  function DelegateInstruction(description, ipIncrement, delegate) {
    this.delegate = delegate;
    DelegateInstruction.__super__.constructor.call(this, description, ipIncrement);
  }

  DelegateInstruction.prototype.execute = function(state) {
    return this.delegate(state);
  };

  return DelegateInstruction;

})(Instruction);

InterpretedInstruction = (function(_super) {

  __extends(InterpretedInstruction, _super);

  function InterpretedInstruction(description, ipIncrement, code) {
    InterpretedInstruction.__super__.constructor.call(this, description, ipIncrement);
    this.updateCode(code);
  }

  InterpretedInstruction.prototype.addCondition = function(conditionCode, statements, fallThrough) {
    var condition, statement, statementTokens, _i, _len, _ref;
    if (fallThrough == null) {
      fallThrough = false;
    }
    condition = Tokeniser.tokenise(conditionCode);
    statementTokens = [];
    _ref = statements.split(Symbol.statementSeparator);
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      statement = _ref[_i];
      statementTokens.push(Tokeniser.tokenise(statement));
    }
    return this.conditions.push({
      condition: condition,
      statements: statementTokens,
      fallThrough: fallThrough
    });
  };

  InterpretedInstruction.prototype.updateCode = function(code) {
    var blocks, caseBlock, cases, condition, contextClause, contextStatement, contextStatements, fallThrough, key, parts, startingSymbol, statements, value, _i, _j, _len, _len1, _ref, _results;
    code = code.replace(/\s+/g, ' ');
    this.conditions = [];
    startingSymbol = code[0];
    if (startingSymbol === Symbol.guard[0]) {
      code = code.slice(Symbol.guard.length);
      startingSymbol = Symbol.guard;
    } else {
      code = code.slice(1);
    }
    parts = code.split(Symbol.context);
    code = parts[0];
    if (parts.length > 1) {
      contextClause = parts[1];
      contextStatements = contextClause.split(Symbol.statementSeparator);
      this.context = {};
      for (_i = 0, _len = contextStatements.length; _i < _len; _i++) {
        contextStatement = contextStatements[_i];
        if (contextStatement.length > 0) {
          _ref = contextStatement.split(Symbol.assign), key = _ref[0], value = _ref[1];
          this.context[key] = Tokeniser.tokenise(value);
        }
      }
    }
    if (startingSymbol === Symbol.conditionTerminator) {
      return this.addCondition(Symbol.boolTrue, code);
    } else if (startingSymbol === Symbol.guard) {
      cases = code.split(Symbol.guard);
      _results = [];
      for (_j = 0, _len1 = cases.length; _j < _len1; _j++) {
        caseBlock = cases[_j];
        blocks = caseBlock.split(Symbol.conditionTerminator);
        fallThrough = false;
        if (blocks.length === 1) {
          blocks = caseBlock.split(Symbol.fallThrough);
          fallThrough = true;
        }
        condition = blocks[0], statements = blocks[1];
        if (condition.length > 0) {
          _results.push(this.addCondition(condition, statements, fallThrough));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    }
  };

  InterpretedInstruction.prototype.execute = function(state) {
    var condition, conditionValue, statement, _i, _j, _len, _len1, _ref, _ref1, _results;
    _ref = this.conditions;
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      condition = _ref[_i];
      conditionValue = Interpreter.interpretCondition(condition.condition, state, this.context);
      if (conditionValue) {
        _ref1 = condition.statements;
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          statement = _ref1[_j];
          Interpreter.interpretStatement(statement, state, this.context);
        }
        if (!condition.fallThrough) {
          break;
        } else {
          _results.push(void 0);
        }
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  };

  return InterpretedInstruction;

})(Instruction);

Interpreter = (function() {

  function Interpreter(tokens, state, context) {
    this.tokens = tokens;
    this.state = state;
    this.context = context;
    this.tokenPos = 0;
    this.acceptedToken = null;
    this.pendingToken = null;
    this.internalAccessible = false;
    this.getToken();
  }

  Interpreter.prototype.getToken = function() {
    if (this.tokenPos !== this.tokens.length) {
      this.pendingToken = this.tokens[this.tokenPos];
      return this.tokenPos += 1;
    } else {
      return this.pendingToken = null;
    }
  };

  Interpreter.prototype.accept = function(tokenType) {
    var accepted;
    accepted = false;
    if (this.pendingToken !== null && this.pendingToken.type === tokenType) {
      this.acceptedToken = this.pendingToken;
      this.getToken();
      accepted = true;
    }
    return accepted;
  };

  Interpreter.prototype.expect = function(tokenType) {
    if (!this.accept(tokenType)) {
      throw new SyntaxError("Expected " + Token.typeString(tokenType));
    }
  };

  Interpreter.prototype.isValidRegister = function(registerName) {
    return (__indexOf.call(this.state.processor.registerNames, registerName) >= 0);
  };

  Interpreter.prototype.bitExpression = function() {
    var value;
    value = this.addExpression();
    while (this.accept(Token.OpBitwise)) {
      switch (this.acceptedToken.value) {
        case Symbol.bitXor:
          value ^= this.addExpression();
          break;
        case Symbol.bitAnd:
          value &= this.addExpression();
          break;
        case Symbol.bitOr:
          value |= this.addExpression();
          break;
        case Symbol.bitRShift:
          value >>= this.addExpression();
          break;
        case Symbol.bitLShift:
          value <<= this.addExpression();
          break;
        default:
          throw new SyntaxError("Unknown bitwise operator: " + this.acceptedToken.value);
      }
    }
    return value;
  };

  Interpreter.prototype.addExpression = function() {
    var value;
    value = this.mulExpression();
    while (this.accept(Token.OpTerm)) {
      switch (this.acceptedToken.value) {
        case Symbol.add:
          value += this.mulExpression();
          break;
        case Symbol.sub:
          value -= this.mulExpression();
          break;
        default:
          throw new SyntaxError("Unknown additive operator: " + this.acceptedToken.value);
      }
    }
    return value;
  };

  Interpreter.prototype.mulExpression = function() {
    var value;
    value = this.unaryExpression();
    while (this.accept(Token.OpFactor)) {
      switch (this.acceptedToken.value) {
        case Symbol.mul:
          value *= this.unaryExpression();
          break;
        case Symbol.div:
          value /= this.unaryExpression();
          break;
        case Symbol.mod:
          value %= this.unaryExpression();
          break;
        default:
          throw new SyntaxError("Unknown multiplicative operator: " + this.acceptedToken.value);
      }
    }
    return value;
  };

  Interpreter.prototype.unaryExpression = function() {
    var isUnary, value;
    isUnary = this.accept(Token.OpUnary);
    value = this.simpleExpression();
    if (isUnary) {
      if (this.acceptedToken.value === Symbol.bitInvert) {
        value = ~value;
      } else {
        throw new SyntaxInterpreterError("Unknown unary operator: " + this.acceptedToken.value);
      }
    }
    return value;
  };

  Interpreter.prototype.simpleExpression = function() {
    var value;
    value = -1;
    if (this.accept(Token.GroupOpen)) {
      value = this.intExpression();
      this.expect(Token.GroupClose);
    } else if (this.accept(Token.Integer)) {
      value = parseInt(this.acceptedToken.value);
    } else if (this.accept(Token.Hex)) {
      value = parseInt(this.acceptedToken.value, 16);
    } else {
      switch (this.pendingToken.type) {
        case Token.RegisterName:
        case Token.DerefOpen:
        case Token.RegRefOpen:
          value = this.identifier();
          break;
        default:
          throw new SyntaxError("Unable to parse expression at: " + this.pendingToken.value);
      }
    }
    return value;
  };

  Interpreter.prototype.identifier = function() {
    var address, identifierName, registerName, registerNumber, value;
    value = 0;
    identifierName = Symbol.unknown;
    if (this.accept(Token.RegisterName)) {
      identifierName = this.acceptedToken.value;
      if (this.isValidRegister(identifierName)) {
        value = this.state.getRegister(identifierName);
      } else if (this.context[identifierName]) {
        value = Interpreter.interpretExpression(this.context[identifierName], this.state, this.context);
      } else {
        throw new SyntaxError("Unknown register or identifier: " + identifierName);
      }
    } else if (this.accept(Token.DerefOpen)) {
      address = this.intExpression();
      this.expect(Token.DerefClose);
      value = this.state.getMemory(address);
    } else if (this.accept(Token.RegRefOpen)) {
      registerNumber = this.intExpression();
      this.expect(Token.RegRefClose);
      if (registerNumber < this.state.processor.numRegisters) {
        registerName = this.state.processor.registerNames[registerNumber];
        value = this.state.getRegister(registerName);
      } else {
        throw new SyntaxError("Register index out of bounds: " + registerNumber);
      }
    } else if (this.accept(Token.Internal)) {
      if (this.internalAccessible) {
        switch (this.acceptedToken.value) {
          case Symbol.bellState:
            value = this.state.numBellRings;
            break;
          case Symbol.cycleState:
            value = this.state.executionStep;
            break;
          default:
            throw new SyntaxError("Unknown internal value: " + this.acceptedToken.value);
        }
      } else {
        throw new SyntaxError("Unrecognised identifier: " + this.pendingToken.value);
      }
    }
    return value;
  };

  Interpreter.prototype.intExpression = function() {
    return this.bitExpression();
  };

  Interpreter.prototype.stringComparison = function() {
    var value;
    value = false;
    if (this.internalAccessible) {
      this.expect(Token.Internal);
      if (this.acceptedToken.value !== Symbol.outputState) {
        throw new SyntaxError("Unknown internal string identifier: " + this.acceptedToken.value);
      }
      this.expect(Token.OpComparison);
      if (this.acceptedToken.value === Symbol.compareEq) {
        this.expect(Token.StringLiteral);
        value = this.state.output === this.acceptedToken.value;
      } else if (this.acceptedToken.value === Symbol.compareNe) {
        this.expect(Token.StringLiteral);
        value = this.state.output !== this.acceptedToken.value;
      } else {
        throw new SyntaxError("Unknown string comparison operator: " + this.acceptedToken.value);
      }
    } else {
      throw new SyntaxError("Internal information inaccessible.");
    }
    return value;
  };

  Interpreter.prototype.boolExpression = function() {
    var leftSide, operator, rightSide, value;
    value = false;
    if (this.accept(Token.BoolLiteral)) {
      switch (this.acceptedToken.value) {
        case Symbol.boolTrue:
        case Symbol.otherwise:
          value = true;
          break;
        case Symbol.boolFalse:
          value = false;
          break;
        default:
          throw new SyntaxError("Unknown boolean literal: " + this.acceptedToken.value);
      }
    } else if (this.accept(Token.GroupOpen)) {
      value = this.condition();
      this.expect(Token.GroupClose);
    } else if (this.pendingToken.type === Token.Internal && pendingToken.value === "output") {
      value = this.stringComparison();
    } else {
      leftSide = this.intExpression();
      this.expect(Token.OpComparison);
      operator = this.acceptedToken.value;
      rightSide = this.intExpression();
      switch (operator) {
        case Symbol.compareGT:
          value = leftSide > rightSide;
          break;
        case Symbol.compareLT:
          value = leftSide < rightSide;
          break;
        case Symbol.compareGE:
          value = leftSide >= rightSide;
          break;
        case Symbol.compareLE:
          value = leftSide <= rightSide;
          break;
        case Symbol.compareEq:
          value = leftSide === rightSide;
          break;
        case Symbol.compareNe:
          value = leftSide !== rightSide;
          break;
        default:
          throw new Error("Unknown comparison operator: " + operator);
      }
    }
    return value;
  };

  Interpreter.prototype.condition = function() {
    var value;
    value = this.boolExpression();
    while (this.accept(Token.OpLogic)) {
      switch (this.acceptedToken.value) {
        case Symbol.boolAnd:
          value = value && this.boolExpression();
          break;
        case Symbol.boolOr:
          value = value || this.boolExpression();
          break;
        default:
          throw new SyntaxError("Unknown boolean operator: " + this.acceptedToken.value);
      }
    }
    return value;
  };

  Interpreter.prototype.assignment = function(oldValue) {
    var newValue, operator;
    if (this.accept(Token.OpAssign)) {
      operator = this.acceptedToken.value;
      newValue = this.intExpression();
      switch (operator) {
        case Symbol.addAssign:
          newValue = oldValue + newValue;
          break;
        case Symbol.subAssign:
          newValue = oldValue - newValue;
          break;
        case Symbol.assign:
          break;
        default:
          throw new SyntaxError("Unknown assignment operator: " + operator);
      }
    } else if (this.accept(Token.OpIncAssign)) {
      newValue = oldValue;
      switch (this.acceptedToken.value) {
        case Symbol.incAssign:
          newValue += 1;
          break;
        case Symbol.decAssign:
          newValue -= 1;
          break;
        default:
          throw new SyntaxError("Unknown increment operator: " + this.acceptedToken.value);
      }
    } else {
      throw new SyntaxError("Unknown assignment: " + this.pendingToken.value);
    }
    return newValue;
  };

  Interpreter.prototype.statement = function() {
    var argumentValue, commandValue, memoryAddress, registerName, registerNumber, value;
    value = 0;
    if (this.accept(Token.RegisterName)) {
      registerName = this.acceptedToken.value;
      if (this.isValidRegister(registerName)) {
        value = this.assignment(this.state.getRegister(registerName));
        return this.state.setRegister(registerName, value);
      } else {
        throw new SyntaxError("Unknown register name: " + registerName);
      }
    } else if (this.accept(Token.DerefOpen)) {
      memoryAddress = this.intExpression();
      this.expect(Token.DerefClose);
      value = this.assignment(this.state.getMemory(memoryAddress));
      return this.state.setMemory(memoryAddress, value);
    } else if (this.accept(Token.RegRefOpen)) {
      registerNumber = this.intExpression();
      this.expect(Token.RegRefClose);
      if (registerNumber < this.state.processor.numRegisters) {
        registerName = this.state.processor.registerNames[registerNumber];
        value = this.assignment(this.state.getRegister(registerName));
        return this.state.setRegister(registerName, value);
      } else {
        throw new SyntaxError("Register reference out of bounds evaluating statement");
      }
    } else if (this.accept(Token.Keyword)) {
      argumentValue = 0;
      switch (this.acceptedToken.value) {
        case Symbol.commandPrint:
        case Symbol.commandPrintASCII:
          commandValue = this.acceptedToken.value;
          this.expect(Token.GroupOpen);
          argumentValue = this.intExpression();
          this.expect(Token.GroupClose);
          if (commandValue === Symbol.commandPrint) {
            return this.state.print(argumentValue);
          } else {
            return this.state.printASCII(argumentValue);
          }
          break;
        case Symbol.commandBell:
          return this.state.ringBell();
        case Symbol.commandHalt:
          return this.state.halt();
        case Symbol.commandNop:
          break;
        default:
          throw new SyntaxError("Unknown command: " + this.acceptedToken.value);
      }
    } else {
      throw new SyntaxError("Unable to parse statement");
    }
  };

  return Interpreter;

})();

Interpreter.interpretStatement = function(statementTokens, state, context) {
  var interpreter;
  interpreter = new Interpreter(statementTokens, state, context);
  return interpreter.statement();
};

Interpreter.interpretCondition = function(conditionTokens, state, context) {
  var interpreter;
  interpreter = new Interpreter(conditionTokens, state, context);
  return interpreter.condition();
};

Interpreter.interpretExpression = function(expressionTokens, state, context) {
  var interpreter;
  interpreter = new Interpreter(expressionTokens, state, context);
  return interpreter.intExpression();
};

Symbol = {
  instructionSeparator: ',',
  conditionTerminator: ':',
  instructionTerminator: '.',
  statementSeparator: ';',
  fallThrough: '?',
  guard: 'case',
  context: 'where',
  otherwise: 'otherwise',
  titleStart: '[',
  descriptionsHeader: '[descriptions]',
  instructionsHeader: '[instructions]',
  add: '+',
  sub: '-',
  mul: '*',
  div: '/',
  mod: '%',
  bitInvert: '~',
  bitAnd: '&',
  bitOr: '|',
  bitLShift: '<<',
  bitRShift: '>>',
  bitXor: '^',
  addAssign: '+=',
  subAssign: '-=',
  incAssign: '++',
  decAssign: '--',
  assign: '=',
  boolAnd: '&&',
  boolOr: '||',
  boolTrue: 'true',
  boolFalse: 'false',
  commandPrint: 'print',
  commandPrintASCII: 'printASCII',
  commandBell: 'bell',
  commandNop: 'nop',
  commandHalt: 'halt',
  outputState: 'output',
  bellState: 'numBellRings',
  cycleState: 'numCycles',
  compareLT: '<',
  compareGT: '>',
  compareGE: '>=',
  compareLE: '<=',
  compareEq: '==',
  compareNe: '!=',
  unknown: '???',
  groupOpen: '(',
  groupClose: ')',
  derefOpen: '[',
  derefClose: ']',
  regrefOpen: '{',
  refregClose: '}',
  hexStart: '#'
};

SyntaxError = (function(_super) {

  __extends(SyntaxError, _super);

  function SyntaxError(syntax) {
    this.name = 'Syntax Error';
    if (syntax) {
      Error.call(this, "Invalid syntax: " + syntax);
    } else {
      Error.call(this, "Invalid syntax");
    }
    Error.captureStackTrace(this, arguments.callee);
  }

  return SyntaxError;

})(Error);

Token = (function() {

  function Token(type, value) {
    this.type = type;
    this.value = value;
  }

  Token.prototype.toString = function() {
    return '(' + this.typeToString() + ', "' + this.value + '")';
  };

  Token.prototype.typeToString = function() {
    return Token.typeString(this.type);
  };

  return Token;

})();

Token.OpAssign = 0;

Token.OpLogic = 1;

Token.OpComparison = 2;

Token.BoolLiteral = 3;

Token.GroupOpen = 4;

Token.GroupClose = 5;

Token.OpTerm = 6;

Token.OpFactor = 7;

Token.Integer = 8;

Token.Keyword = 9;

Token.RegisterName = 10;

Token.DerefOpen = 11;

Token.DerefClose = 12;

Token.OpIncAssign = 13;

Token.OpBitwise = 14;

Token.OpUnary = 15;

Token.RegRefOpen = 16;

Token.RegRefClose = 17;

Token.Hex = 18;

Token.Internal = 19;

Token.StringLiteral = 20;

Token.typeString = function(type) {
  var typeNames;
  return typeNames = ["assignment", "logical operator", "logical comparison", "boolean literal", "open group", "close group", "term operator", "factor operator", "integer", "keyword", "register name", "open dereference", "close dereference", "modifying assignment", "bitwise operator", "unary operator", "register reference open", "register reference close", "hex hash", "internal keyword", "string literal"];
};

Tokeniser = (function() {

  function Tokeniser() {
    this.position = 0;
    this.tokens = [];
    this.code = "";
  }

  Tokeniser.prototype.addToken = function(type, value) {
    this.tokens.push(new Token(type, value));
    return this.position += value.length;
  };

  Tokeniser.prototype.throwError = function() {
    console.log('Error');
    throw new SyntaxError(this.code[this.position]);
  };

  Tokeniser.prototype.tokeniseComparison = function() {
    var c, couplet;
    couplet = this.code.substring(this.position, this.position + 2);
    c = this.code[this.position];
    if (couplet === Symbol.compareLE || couplet === Symbol.compareGE || couplet === Symbol.compareNe || couplet === Symbol.compareEq) {
      return this.addToken(Token.OpComparison, couplet);
    } else if (c === Symbol.compareLT || c === Symbol.compareGT) {
      return this.addToken(Token.OpComparison, c);
    }
  };

  Tokeniser.prototype.tokeniseEqualsSign = function() {
    var couplet;
    couplet = this.code.substring(this.position, this.position + 2);
    if (couplet === Symbol.compareEq) {
      return this.addToken(Token.OpComparison, couplet);
    } else {
      return this.addToken(Token.OpAssign, Symbol.assign);
    }
  };

  Tokeniser.prototype.tokeniseLogicOp = function() {
    var c, couplet;
    couplet = this.code.substring(this.position, this.position + 2);
    c = this.code[this.position];
    if (couplet === Symbol.boolAnd || couplet === Symbol.boolOr) {
      return this.addToken(Token.OpLogic, couplet);
    } else {
      return this.addToken(Token.OpBitwise, c);
    }
  };

  Tokeniser.prototype.tokeniseBitshift = function() {
    var couplet;
    String(couplet = code.substring(this.position, this.position + 2));
    if (couplet === Symbol.bitLShift || couplet === Symbol.bitRShift) {
      return this.addToken(Token.OpBitwise, couplet);
    } else {
      return this.throwError();
    }
  };

  Tokeniser.prototype.tokeniseAddOp = function() {
    var c, couplet;
    couplet = this.code.substring(this.position, this.position + 2);
    c = this.code[this.position];
    if (couplet === Symbol.addAssign || couplet === Symbol.subAssign) {
      return this.addToken(Token.OpAssign, couplet);
    } else if (couplet === Symbol.incAssign || couplet === Symbol.decAssign) {
      return this.addToken(Token.OpIncAssign, couplet);
    } else {
      return this.addToken(Token.OpTerm, c);
    }
  };

  Tokeniser.prototype.isDigit = function(c) {
    return c >= '0' && c <= '9';
  };

  Tokeniser.prototype.isHexDigit = function(c) {
    return this.isDigit(c) || (c >= 'A' && c <= 'F');
  };

  Tokeniser.prototype.isLetter = function(c) {
    return c === '_' || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
  };

  Tokeniser.prototype.isAlphanumeric = function(c) {
    return this.isDigit(c) || this.isLetter(c);
  };

  Tokeniser.prototype.tokeniseInteger = function() {
    var digitStr, i;
    digitStr = "";
    i = this.position;
    while ((i < this.code.length) && this.isDigit(this.code[i])) {
      digitStr += this.code[i];
      i += 1;
    }
    return this.addToken(Token.Integer, digitStr);
  };

  Tokeniser.prototype.tokeniseHex = function() {
    var digitStr, i;
    digitStr = "";
    this.position++;
    i = this.position;
    while ((i < this.code.length) && this.isHexDigit(this.code[i])) {
      digitStr += this.code[i];
      i += 1;
    }
    return this.addToken(Token.Hex, digitStr);
  };

  Tokeniser.prototype.tokeniseStringLiteral = function() {
    var i, stringVal;
    i = this.position;
    stringVal = "";
    i += 1;
    while ((i < this.code.length) && this.code[i] !== '"') {
      stringVal += this.code[i];
      i += 1;
    }
    this.addToken(Token.StringLiteral, stringVal);
    return this.position += 2;
  };

  Tokeniser.prototype.tokeniseKeyword = function() {
    var booleanLiterals, commands, i, internalKeywords, keywordStr;
    keywordStr = "";
    i = this.position;
    while ((i < this.code.length) && this.isAlphanumeric(this.code[i])) {
      keywordStr += this.code[i];
      i += 1;
    }
    booleanLiterals = [Symbol.boolTrue, Symbol.boolFalse, Symbol.otherwise];
    commands = [Symbol.commandPrint, Symbol.commandPrintASCII, Symbol.commandBell, Symbol.commandHalt, Symbol.commandNop];
    internalKeywords = [Symbol.bellState, Symbol.outputState, Symbol.cycleState];
    if ((__indexOf.call(booleanLiterals, keywordStr) >= 0)) {
      return this.addToken(Token.BoolLiteral, keywordStr);
    } else if ((__indexOf.call(commands, keywordStr) >= 0)) {
      return this.addToken(Token.Keyword, keywordStr);
    } else if ((__indexOf.call(internalKeywords, keywordStr) >= 0)) {
      return this.addToken(Token.Internal, keywordStr);
    } else {
      return this.addToken(Token.RegisterName, keywordStr);
    }
  };

  Tokeniser.prototype.tokenise = function(code) {
    var c;
    this.code = code;
    this.tokens = [];
    this.position = 0;
    while (this.position !== this.code.length) {
      c = this.code[this.position];
      switch (c) {
        case '(':
          this.addToken(Token.GroupOpen, c);
          break;
        case ')':
          this.addToken(Token.GroupClose, c);
          break;
        case '[':
          this.addToken(Token.DerefOpen, c);
          break;
        case ']':
          this.addToken(Token.DerefClose, c);
          break;
        case '{':
          this.addToken(Token.RegRefOpen, c);
          break;
        case '}':
          this.addToken(Token.RegRefClose, c);
          break;
        case '*':
        case '/':
        case '%':
          this.addToken(Token.OpFactor, c);
          break;
        case '~':
          this.addToken(Token.OpUnary, c);
          break;
        case '+':
        case '-':
          this.tokeniseAddOp();
          break;
        case '<':
        case '>':
        case '!':
          if (this.code[this.position + 1] === c) {
            this.tokeniseBitshift();
          } else {
            this.tokeniseComparison();
          }
          break;
        case '=':
          this.tokeniseEqualsSign();
          break;
        case '#':
          this.tokeniseHex();
          break;
        case '&':
        case '|':
        case '^':
          this.tokeniseLogicOp();
          break;
        case '"':
          this.tokeniseStringLiteral();
          break;
        default:
          if (this.isDigit(c)) {
            this.tokeniseInteger();
          } else if (this.isLetter(c)) {
            this.tokeniseKeyword();
          } else {
            this.throwError();
          }
      }
    }
    return this.tokens;
  };

  return Tokeniser;

})();

Tokeniser.tokenise = function(code) {
  return (new Tokeniser()).tokenise(code);
};

InterpretedProcessor = (function(_super) {

  __extends(InterpretedProcessor, _super);

  function InterpretedProcessor(definition, changeHandler) {
    InterpretedProcessor.__super__.constructor.call(this, '', changeHandler);
    this.updateDefinition(definition);
  }

  InterpretedProcessor.prototype.isTitleLine = function(line) {
    return line.trim()[0] === Symbol.titleStart;
  };

  InterpretedProcessor.prototype.addLineToDict = function(dict, line) {
    var key, property, value;
    line = line.trim();
    if (line !== '') {
      property = line.split(Symbol.conditionTerminator);
      key = property[0].trim();
      value = property.slice(1).join(Symbol.conditionTerminator).trim();
      return dict[key] = value;
    }
  };

  InterpretedProcessor.prototype.isDigit = function(c) {
    return c >= '0' && c <= '9';
  };

  InterpretedProcessor.prototype.extractHeader = function(code) {
    var end, header, i, start;
    header = [];
    i = 0;
    start = i;
    while ((i !== code.length) && (code[i] !== Symbol.instructionSeparator)) {
      i += 1;
    }
    end = i;
    header.push(parseInt(code.substring(start, end)));
    i += 1;
    start = i;
    while ((i !== code.length) && this.isDigit(code[i])) {
      i += 1;
    }
    end = i;
    header.push(parseInt(code.substring(start, end)));
    return header;
  };

  InterpretedProcessor.prototype.extractCodeSection = function(code) {
    var codeStart, i, _i, _ref;
    codeStart = 0;
    for (i = _i = 0, _ref = code.length; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
      if ((code[i] === Symbol.conditionTerminator) || ((code.substring(i, i + Symbol.guard.length)) === Symbol.guard)) {
        break;
      }
    }
    return code.slice(i);
  };

  InterpretedProcessor.prototype.addInstructionCode = function(code, descriptions) {
    var instrCode, instrNum, ipInc, _ref;
    _ref = this.extractHeader(code), instrNum = _ref[0], ipInc = _ref[1];
    instrCode = this.extractCodeSection(code);
    return this.instructions[instrNum] = new InterpretedInstruction(descriptions[instrNum], ipInc, instrCode);
  };

  InterpretedProcessor.prototype.updateDefinition = function(definition) {
    var code, descriptions, instructionCode, instructionCodes, lineNum, lines, properties, regName, regNames, _i, _len, _results;
    properties = {};
    descriptions = {};
    this.instructions = [];
    lines = definition.split('\n');
    lineNum = 0;
    while (!(this.isTitleLine(lines[lineNum]))) {
      this.addLineToDict(properties, lines[lineNum]);
      lineNum += 1;
    }
    this.name = properties.name;
    this.memoryBitSize = parseInt(properties.memoryBitSize);
    this.numMemoryAddresses = parseInt(properties.numMemoryAddresses);
    this.registerBitSize = parseInt(properties.registerBitSize);
    regNames = properties.registerNames.split(Symbol.instructionSeparator);
    this.setRegisterNames((function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = regNames.length; _i < _len; _i++) {
        regName = regNames[_i];
        _results.push(regName.trim());
      }
      return _results;
    })());
    if (lines[lineNum].trim() === Symbol.descriptionsHeader) {
      lineNum += 1;
      while (!(this.isTitleLine(lines[lineNum]))) {
        this.addLineToDict(descriptions, lines[lineNum]);
        lineNum += 1;
      }
    } else {
      throw new SyntaxError('Descriptions must be listed before instructions.');
    }
    code = '';
    if (lines[lineNum].trim() === Symbol.instructionsHeader) {
      lineNum += 1;
      code = lines.slice(lineNum).join('');
      code = code.replace(/\s+/g, '');
    } else {
      throw new SyntaxError('No Instruction Set Defined');
    }
    instructionCodes = code.split(Symbol.instructionTerminator);
    _results = [];
    for (_i = 0, _len = instructionCodes.length; _i < _len; _i++) {
      instructionCode = instructionCodes[_i];
      _results.push(this.addInstructionCode(instructionCode, descriptions));
    }
    return _results;
  };

  return InterpretedProcessor;

})(Processor);

Processor4917 = (function(_super) {

  __extends(Processor4917, _super);

  function Processor4917(changeHandler) {
    var add, decrementR0, decrementR1, halt, incrementR0, incrementR1, ins, jump, jumpIfR0is0, jumpIfR0not0, loadR0, loadR1, print, ringBell, storeR0, storeR1, subtract;
    Processor4917.__super__.constructor.call(this, "4917", changeHandler);
    this.memoryBitSize = 4;
    this.registerBitSize = 4;
    this.numMemoryAddresses = 16;
    this.setRegisterNames(['IP', 'IS', 'R0', 'R1']);
    halt = function(state) {
      return state.isHalted = true;
    };
    add = function(state) {
      var r0, r1;
      r0 = state.getRegister("R0");
      r1 = state.getRegister("R1");
      return state.setRegister("R0", r0 + r1);
    };
    subtract = function(state) {
      var r0, r1;
      r0 = state.getRegister("R0");
      r1 = state.getRegister("R1");
      return state.setRegister("R0", r0 - r1);
    };
    incrementR0 = function(state) {
      var r0;
      r0 = state.getRegister("R0");
      return state.setRegister("R0", r0 + 1);
    };
    incrementR1 = function(state) {
      var r1;
      r1 = state.getRegister("R1");
      return state.setRegister("R1", r1 + 1);
    };
    decrementR0 = function(state) {
      var r0;
      r0 = state.getRegister("R0");
      return state.setRegister("R0", r0 - 1);
    };
    decrementR1 = function(state) {
      var r1;
      r1 = state.getRegister("R1");
      return state.setRegister("R1", r1 - 1);
    };
    ringBell = function(state) {
      return state.ringBell();
    };
    print = function(state) {
      var data, ip;
      ip = state.getRegister("IP");
      data = state.getMemory(ip - 1);
      return state.print(data);
    };
    loadR0 = function(state) {
      var address, ip;
      ip = state.getRegister("IP");
      address = state.getMemory(ip - 1);
      return state.setRegister("R0", state.getMemory(address));
    };
    loadR1 = function(state) {
      var address, ip;
      ip = state.getRegister("IP");
      address = state.getMemory(ip - 1);
      return state.setRegister("R1", state.getMemory(address));
    };
    storeR0 = function(state) {
      var address, ip;
      ip = state.getRegister("IP");
      address = state.getMemory(ip - 1);
      return state.setMemory(address, state.getRegister("R0"));
    };
    storeR1 = function(state) {
      var address, ip;
      ip = state.getRegister("IP");
      address = state.getMemory(ip - 1);
      return state.setMemory(address, state.getRegister("R1"));
    };
    jump = function(state) {
      var address, ip;
      ip = state.getRegister("IP");
      address = state.getMemory(ip - 1);
      return state.setRegister("IP", address);
    };
    jumpIfR0is0 = function(state) {
      var address, ip;
      if ((state.getRegister("R0")) === 0) {
        ip = state.getRegister("IP");
        address = state.getMemory(ip - 1);
        return state.setRegister("IP", address);
      }
    };
    jumpIfR0not0 = function(state) {
      var address, ip;
      if ((state.getRegister("R0")) !== 0) {
        ip = state.getRegister("IP");
        address = state.getMemory(ip - 1);
        return state.setRegister("IP", address);
      }
    };
    ins = function(description, ipIncrement, delegate) {
      return new DelegateInstruction(description, ipIncrement, delegate);
    };
    this.instructions = [ins("Halt", 1, halt), ins("Add (R0 = R0 + R1)", 1, add), ins("Subtract (R0 = R0 - R1)", 1, subtract), ins("Increment R0 (R0 = R0 + 1)", 1, incrementR0), ins("Increment R1 (R1 = R1 + 1)", 1, incrementR1), ins("Decrement R0 (R0 = R0 - 1)", 1, decrementR0), ins("Decrement R1 (R1 = R1 - 1)", 1, decrementR1), ins("Ring Bell", 1, ringBell), ins("Print <data> (numerical value is printed)", 2, print), ins("Load value at address <data> into R0", 2, loadR0), ins("Load value at address <data> into R1", 2, loadR1), ins("Store R0 into address <data>", 2, storeR0), ins("Store R1 into address <data>", 2, storeR1), ins("Jump to address <data>", 2, jump), ins("Jump to address <data> if R0 == 0", 2, jumpIfR0is0), ins("Jump to address <data> if R0 != 0", 2, jumpIfR0not0)];
  }

  return Processor4917;

})(Processor);
