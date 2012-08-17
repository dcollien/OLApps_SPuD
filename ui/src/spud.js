var Chip, CircuitBoard;

Chip = (function() {

  function Chip(definition) {
    var _this = this;
    this.readyCallbacks = [];
    this.updateCallbacks = [];
    if (this.supportsWorkers()) {
      this.worker = new Worker('./src/spudEmu.js');
      this.init(definition);
    } else {
      $.getScript('./src/spudEmu.js', function() {
        _this.worker = new BrowserEmu();
        return _this.init(definition);
      });
    }
  }

  Chip.prototype.init = function(definition) {
    var _this = this;
    this.worker.onmessage(function(event) {
      var receivedData;
      receivedData = JSON.parse(event.data);
      return _this.receive(receivedData.method, receivedData.data);
    });
    return this.worker.postMessage(JSON.stringify({
      method: 'init',
      data: definition
    }));
  };

  Chip.prototype.supportsWorkers = function() {
    return false;
  };

  Chip.prototype.onReady = function(callback) {
    return this.readyCallbacks.push(callback);
  };

  Chip.prototype.onUpdate = function(callback) {
    return this.updateCallbacks.push(callback);
  };

  Chip.prototype.reset = function() {
    return this.worker.postMessage('reset');
  };

  Chip.prototype.step = function() {
    return this.worker.postMessage('step');
  };

  Chip.prototype.run = function() {
    return this.worker.postMessage('run');
  };

  Chip.prototype.receive = function(method, data) {
    var action, args, callback, state, _i, _j, _len, _len1, _ref, _ref1, _results, _results1;
    switch (method) {
      case 'ready':
        _ref = this.readyCallbacks;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          callback = _ref[_i];
          _results.push(callback(data));
        }
        return _results;
        break;
      case 'update':
        state = data.state;
        action = data.action;
        args = data["arguments"];
        _ref1 = this.updateCallbacks;
        _results1 = [];
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          callback = _ref1[_j];
          _results1.push(callback(state, action, args));
        }
        return _results1;
        break;
      case 'report':
        return alert(data);
    }
  };

  return Chip;

})();

CircuitBoard = (function() {

  function CircuitBoard(selector, definition) {
    var _this = this;
    this.selector = selector;
    this.definition = definition;
    this.isOn = false;
    this.chip = new Chip(this.definition);
    this.isReady = false;
    this.build();
    this.chip.onReady(function(event) {
      _this.updateUI(event);
      _this.isReady = true;
      return _this.togglePower();
    });
    this.chip.onUpdate(function(state, action, args) {
      var executionStep, pipelineStep;
      switch (action) {
        case 'ringBell':
          return _this.ringBell();
        case 'print':
        case 'printASCII':
          return _this.output.text(state.output);
        case 'setRegister':
          return console.log(action, args);
        case 'setMemory':
          return console.log(action, args);
        case 'nextStep':
          pipelineStep = args[0], executionStep = args[1];
          return _this.updateLEDs(pipelineStep, executionStep);
        case 'halt':
          return console.log(action);
        default:
          return _this.updateAll(state);
      }
    });
  }

  CircuitBoard.prototype.updateLEDs = function(pipelineStep, executionStep) {
    if (!this.isOn) {
      return;
    }
    $('.ledOn').removeClass('ledOn');
    this.ledOverlay.show().removeClass('fetch').removeClass('increment').removeClass('execute');
    switch (pipelineStep) {
      case 0:
        this.fetchLED.addClass('ledOn');
        return this.ledOverlay.addClass('fetch');
      case 1:
        this.incrementLED.addClass('ledOn');
        return this.ledOverlay.addClass('increment');
      case 2:
        this.executeLED.addClass('ledOn');
        return this.ledOverlay.addClass('execute');
    }
  };

  CircuitBoard.prototype.updateAll = function(state) {
    this.updateLEDs(state.pipelineStep, state.executionStep);
    return console.log(state);
  };

  CircuitBoard.prototype.togglePower = function() {
    if (!this.isReady) {
      return;
    }
    if (this.isOn) {
      this.background.removeClass('on');
      this.isOn = false;
      $('.ledOn').removeClass('ledOn');
      return this.ledOverlay.hide();
    } else {
      this.background.addClass('on');
      this.isOn = true;
      return this.reset();
    }
  };

  CircuitBoard.prototype.reset = function() {
    if (this.isOn) {
      return this.chip.reset();
    }
  };

  CircuitBoard.prototype.run = function() {
    if (this.isOn) {
      return this.chip.run();
    }
  };

  CircuitBoard.prototype.step = function() {
    if (this.isOn) {
      return this.chip.step();
    }
  };

  CircuitBoard.prototype.ringBell = function() {
    var _this = this;
    this.bell.stop(true, true);
    this.bell.addClass('ringing');
    return this.bell.fadeOut(800, function() {
      _this.bell.removeClass('ringing');
      return _this.bell.show();
    });
  };

  CircuitBoard.prototype.updateUI = function(properties) {
    var $cell, $headers, $memoryContainer, $registerContainer, $registers, $row, $table, cellNum, i, j, numAddresses, numCols, numRows, registerName, _i, _j, _k, _len, _ref, _ref1;
    this.chipName.append($('<span>').text(properties.name));
    $memoryContainer = $('<div class="board-memory-container">');
    $table = $('<table class="table table-bordered table-striped board-memory-table">');
    numAddresses = properties.numMemoryAddresses;
    numRows = Math.min(8, Math.floor(Math.sqrt(numAddresses)));
    numCols = Math.min(8, numAddresses / numRows);
    cellNum = 0;
    for (i = _i = 0; 0 <= numRows ? _i < numRows : _i > numRows; i = 0 <= numRows ? ++_i : --_i) {
      $row = $('<tr>');
      for (j = _j = 0, _ref = numCols + 1; 0 <= _ref ? _j < _ref : _j > _ref; j = 0 <= _ref ? ++_j : --_j) {
        if (j === 0) {
          $cell = $('<th>');
          $cell.text(cellNum);
        } else {
          $cell = $('<td>');
          $cell.attr('id', 'memory-' + cellNum);
          cellNum += 1;
        }
        $row.append($cell);
      }
      $table.append($row);
    }
    $memoryContainer.append($('<center>').append($table));
    this.chipBox.append($memoryContainer);
    $registerContainer = $('<div class="board-register-container">');
    $table = $('<table class="table table-bordered table-striped board-register-table">');
    $headers = $('<tr>');
    $registers = $('<tr>');
    _ref1 = properties.registerNames;
    for (_k = 0, _len = _ref1.length; _k < _len; _k++) {
      registerName = _ref1[_k];
      $headers.append($('<th>').text(registerName));
      $registers.append($('<td>'));
    }
    $table.append($headers);
    $table.append($registers);
    $registerContainer.append($('<center>').append($table));
    return this.chipBox.append($registerContainer);
  };

  CircuitBoard.prototype.build = function() {
    var _this = this;
    this.board = $(this.selector);
    this.background = $('<div class="board-bg">');
    this.powerSwitch = $('<div class="board-power">');
    this.bell = $('<div class="board-bell">');
    this.fetchLED = $('<div class="board-fetch">');
    this.incrementLED = $('<div class="board-increment">');
    this.executeLED = $('<div class="board-execute">');
    this.ledOverlay = $('<div class="board-ledOverlay">');
    this.resetButton = $('<div class="board-reset">');
    this.runButton = $('<div class="board-run">');
    this.stepButton = $('<div class="board-step">');
    this.output = $('<div class="board-output">');
    this.chipName = $('<div class="board-chip">');
    this.chipBox = $('<div class="board-chipbox arrow_box">');
    this.chipBox.hide();
    this.chipName.tooltip({
      placement: 'bottom',
      title: 'View Memory and Registers'
    });
    this.ledOverlay.tooltip({
      placement: 'top',
      title: 'Next step to perform'
    });
    this.resetButton.tooltip({
      placement: 'left',
      title: 'Reset to starting state'
    });
    this.runButton.tooltip({
      placement: 'left',
      title: 'Run until halted'
    });
    this.stepButton.tooltip({
      placement: 'bottom',
      title: 'Perform a single step'
    });
    this.powerSwitch.click(function() {
      return _this.togglePower();
    });
    this.resetButton.click(function() {
      return _this.reset();
    });
    this.runButton.click(function() {
      return _this.run();
    });
    this.stepButton.click(function() {
      return _this.step();
    });
    this.chipName.click(function() {
      return _this.chipBox.fadeToggle();
    });
    this.board.html(this.background);
    return this.background.append(this.powerSwitch).append(this.bell).append(this.fetchLED).append(this.incrementLED).append(this.executeLED).append(this.resetButton).append(this.runButton).append(this.stepButton).append(this.chipName).append(this.output).append(this.ledOverlay).append(this.chipBox);
  };

  return CircuitBoard;

})();

$.fn.extend({
  spud: function() {
    var definition, options, opts, self;
    self = $.fn.spud;
    switch (arguments[0]) {
      case 'setDefinition':
        definition = arguments[1];
        return $(this);
      default:
        options = arguments[0];
        if (typeof options === 'string') {
          options = {
            definition: options
          };
        }
        opts = $.extend({}, self.defaultOptions, options);
        return $(this).each(function(index, element) {
          return self.init(element, opts);
        });
    }
  }
});

$.extend($.fn.spud, {
  defaultOptions: {},
  init: function(element, options) {
    var circuitBoard;
    circuitBoard = new CircuitBoard(element, options.definition);
    return $(element).data('spud', circuitBoard);
  }
});
