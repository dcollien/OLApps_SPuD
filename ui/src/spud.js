var Chip, CircuitBoard;

Chip = (function() {

  function Chip(definition) {
    var _this = this;
    this.runSpeed = 50;
    this.isRunning = false;
    this.isSpeedRunning = false;
    this.readyCallbacks = [];
    this.updateCallbacks = [];
    this.runUpdateCallbacks = [];
    if (this.supportsWorkers()) {
      if (typeof console !== "undefined" && console !== null) {
        console.log('Using Worker');
      }
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
    this.worker.onmessage = function(event) {
      var receivedData;
      receivedData = JSON.parse(event.data);
      return _this.receive(receivedData.method, receivedData.data);
    };
    return this.worker.postMessage(JSON.stringify({
      method: 'init',
      data: definition
    }));
  };

  Chip.prototype.supportsWorkers = function() {
    return (typeof window.Worker) === 'function';
  };

  Chip.prototype.onReady = function(callback) {
    return this.readyCallbacks.push(callback);
  };

  Chip.prototype.onUpdate = function(callback) {
    return this.updateCallbacks.push(callback);
  };

  Chip.prototype.onRunUpdate = function(callback) {
    return this.runUpdateCallbacks.push(callback);
  };

  Chip.prototype.reset = function() {
    return this.worker.postMessage('reset');
  };

  Chip.prototype.step = function() {
    return this.worker.postMessage('step');
  };

  Chip.prototype.run = function() {
    if (this.isRunning) {
      return this.isRunning = false;
    } else {
      this.isRunning = true;
      return this.runUpdate();
    }
  };

  Chip.prototype.runUpdate = function() {
    var _this = this;
    this.step();
    if (this.isRunning) {
      return setTimeout((function() {
        return _this.runUpdate();
      }), this.runSpeed);
    }
  };

  Chip.prototype.speedRun = function() {
    this.isSpeedRunning = true;
    return this.worker.postMessage('run');
  };

  Chip.prototype.setState = function(state) {
    return this.worker.postMessage(JSON.stringify({
      method: 'updateState',
      data: state
    }));
  };

  Chip.prototype.updateRegister = function(registerName, value) {
    return this.worker.postMessage(JSON.stringify({
      method: 'updateRegister',
      data: {
        'registerName': registerName,
        'value': value
      }
    }));
  };

  Chip.prototype.updateMemory = function(memoryAddress, value) {
    return this.worker.postMessage(JSON.stringify({
      method: 'updateMemory',
      data: {
        'memoryAddress': memoryAddress,
        'value': value
      }
    }));
  };

  Chip.prototype.receive = function(method, data) {
    var action, args, callback, state, _i, _j, _k, _len, _len1, _len2, _ref, _ref1, _ref2, _results, _results1, _results2;
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
      case 'runUpdate':
        _ref1 = this.runUpdateCallbacks;
        _results1 = [];
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          callback = _ref1[_j];
          _results1.push(callback(data));
        }
        return _results1;
        break;
      case 'update':
        state = data.state;
        action = data.action;
        args = data["arguments"];
        if (data.state.isHalted) {
          this.isRunning = false;
          this.isSpeedRunning = false;
        }
        _ref2 = this.updateCallbacks;
        _results2 = [];
        for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
          callback = _ref2[_k];
          _results2.push(callback(state, action, args));
        }
        return _results2;
        break;
      case 'report':
        if (data.reason === 'runPaused') {
          this.isSpeedRunning = false;
          return alert(data.message);
        }
        break;
    }
  };

  return Chip;

})();

CircuitBoard = (function() {

  function CircuitBoard(selector, definition, startingState, audio) {
    var _this = this;
    this.selector = selector;
    this.definition = definition;
    this.audio = audio;
    this.soundEnabled = false;
    if (this.audio != null) {
      this.soundEnabled = true;
    }
    this.isOn = false;
    this.chip = new Chip(this.definition);
    this.isReady = false;
    this.isHalted = false;
    this.effectsEnabled = false;
    this.build();
    this.chip.onReady(function(event) {
      var memory, name, parts, registerVal, registers, value, _i, _len, _ref, _results;
      _this.buildInspector(event);
      _this.isReady = true;
      _this.togglePower();
      if (startingState != null) {
        _this.chip.reset();
        parts = startingState.replace('[memory]', '').split('[registers]');
        if (parts.length !== 2) {
          return;
        }
        try {
          memory = parts[0], registers = parts[1];
          memory = memory.replace(/\s+/g, ' ');
          registers = registers.replace(/\s+/g, ' ');
          _this.uploadCode(memory);
          _ref = registers.split(' ');
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            registerVal = _ref[_i];
            registerVal = registerVal.replace(/\s+/g, '');
            if (registerVal !== '') {
              parts = registerVal.split('=');
              if (parts.length !== 2) {
                continue;
              }
              name = parts[0], value = parts[1];
              _results.push(_this.chip.updateRegister(name, parseInt(value)));
            } else {
              _results.push(void 0);
            }
          }
          return _results;
        } catch (error) {
          return console.log(error);
        }
      }
    });
    this.chip.onUpdate(function(state, action, args) {
      if (!_this.isOn) {
        return;
      }
      return _this.handleUpdate(state, action, args);
    });
    this.chip.onRunUpdate(function(state) {
      return _this.updateAll(state);
    });
  }

  CircuitBoard.prototype.playSound = function(sound) {
    if (!this.soundEnabled) {
      return;
    }
    if (this.playing != null) {
      this.playing.remove();
    }
    this.playing = $('<embed style="height:0" loop="false" autostart="true" hidden="true"/>').attr('src', sound);
    return this.playing.appendTo('body');
  };

  CircuitBoard.prototype.backgroundSound = function(sound) {
    if (!this.soundEnabled) {
      return;
    }
    if (this.bgSound != null) {
      this.bgSound.remove();
    }
    this.bgSound = $('<embed style="height:0" loop="true" autostart="true" hidden="true"/>').attr('src', sound);
    return this.bgSound.appendTo('body');
  };

  CircuitBoard.prototype.handleUpdate = function(state, action, args) {
    var address, cycleText, executionStep, pipelineStep, register, value;
    this.currentState = state;
    switch (action) {
      case 'ringBell':
        this.ringBell();
        return this.updateRings(state.numBellRings);
      case 'print':
      case 'printASCII':
        return this.updateOutput(state);
      case 'setRegister':
        register = args[0], value = args[1];
        if (register === 'IP') {
          this.highlightCell(value);
        }
        return $('#register-' + register).val(this.formatValue(value));
      case 'setMemory':
        address = args[0], value = args[1];
        return $('#memory-' + address).val(this.formatValue(value));
      case 'nextStep':
        pipelineStep = args[0], executionStep = args[1];
        this.updateIP(state);
        this.updateLEDs(pipelineStep, executionStep);
        this.animateStep(pipelineStep);
        cycleText = executionStep + ' execution cycle';
        if (executionStep !== 1) {
          cycleText += 's';
        }
        return this.cycleLabel.text(cycleText);
      case 'halt':
        return this.halt();
      default:
        return this.updateAll(state);
    }
  };

  CircuitBoard.prototype.updateAll = function(state) {
    var cell, cycleText, memoryValue, reg, regIndex, regValue, _i, _j, _len, _ref, _ref1;
    if (!(state != null)) {
      return;
    }
    this.currentState = state;
    this.updateLEDs(state.pipelineStep, state.executionStep);
    this.updateIP(state);
    for (cell = _i = 0, _ref = state.memory.length; 0 <= _ref ? _i < _ref : _i > _ref; cell = 0 <= _ref ? ++_i : --_i) {
      memoryValue = state.memory[cell];
      $('#memory-' + cell).val(this.formatValue(memoryValue));
    }
    if (this.properties != null) {
      _ref1 = this.properties.registerNames;
      for (_j = 0, _len = _ref1.length; _j < _len; _j++) {
        reg = _ref1[_j];
        regIndex = this.properties.registerIndexLookup[reg];
        regValue = state.registers[regIndex];
        $('#register-' + reg).val(this.formatValue(regValue));
      }
    }
    this.updateRings(state.numBellRings);
    this.updateOutput(state);
    cycleText = state.executionStep + ' execution cycle';
    if (state.executionStep !== 1) {
      cycleText += 's';
    }
    this.cycleLabel.text(cycleText);
    if (state.isHalted) {
      return this.halt();
    }
  };

  CircuitBoard.prototype.updateOutput = function(state) {
    var textLimit;
    textLimit = 8194;
    if ((state.output.length > textLimit) && this.chip.isSpeedRunning) {

    } else if (state.output.length > textLimit) {
      return this.output.text(' ... \n' + state.output.slice(state.output.length - textLimit, state.output.length));
    } else {
      return this.output.text(state.output);
    }
  };

  CircuitBoard.prototype.updateRings = function(bellRings) {
    var plural;
    if (bellRings === 1) {
      plural = '';
    } else {
      plural = 's';
    }
    this.bellOverlay.tooltip('destroy');
    return this.bellOverlay.tooltip({
      placement: 'top',
      title: bellRings + ' bell ring' + plural
    });
  };

  CircuitBoard.prototype.highlightCell = function(cell) {
    $('.highlighted-cell').removeClass('highlighted-cell');
    return $('#memory-' + cell).addClass('highlighted-cell');
  };

  CircuitBoard.prototype.updateIP = function(state) {
    var ip;
    if (this.properties != null) {
      ip = this.properties.registerIndexLookup['IP'];
      return this.highlightCell(state.registers[ip]);
    }
  };

  CircuitBoard.prototype.clearHighlights = function() {
    $('.fetch-highlight').removeClass('fetch-highlight');
    $('.execute-highlight').removeClass('execute-highlight');
    return $('.increment-highlight').removeClass('increment-highlight');
  };

  CircuitBoard.prototype.areEffectsEnabled = function() {
    return (this.effectsEnabled || !this.chip.isRunning) && !this.chip.isSpeedRunning;
  };

  CircuitBoard.prototype.animateStep = function(pipelineStep) {
    var animateSpeed, currentCell, pos, targetCell, targetPos, targetValue,
      _this = this;
    if (!this.areEffectsEnabled()) {
      return;
    }
    this.clearHighlights();
    if (this.movingValue) {
      this.movingValue.stop(true, true).remove();
    }
    switch (pipelineStep) {
      case 0:
        return $('#register-IS').addClass('execute-highlight');
      case 1:
        currentCell = $('.highlighted-cell');
        if (currentCell.is(':visible')) {
          this.movingValue = $('<span class="board-moving-value">').text(currentCell.val());
          this.chipBox.append(this.movingValue);
          pos = currentCell.position();
          this.movingValue.css({
            left: pos.left + 'px',
            top: pos.top + 'px',
            width: currentCell.width() + 'px',
            padding: currentCell.css('padding')
          });
          targetCell = $('#register-IS');
          targetValue = targetCell.val();
          targetCell.val('');
          targetPos = targetCell.position();
          if (this.chip.isRunning) {
            animateSpeed = this.chip.runSpeed;
          } else {
            animateSpeed = 'slow';
          }
          return this.movingValue.animate({
            left: targetPos.left + 'px',
            top: targetPos.top + 'px',
            width: targetCell.width() + 'px',
            padding: targetCell.css('padding')
          }, animateSpeed, function() {
            if (_this.movingValue) {
              _this.movingValue.remove();
            }
            _this.clearHighlights();
            targetCell.val(targetValue);
            return targetCell.addClass('fetch-highlight');
          });
        } else {
          return $('#register-IS').addClass('fetch-highlight');
        }
        break;
      case 2:
        return $('#register-IP').addClass('increment-highlight');
    }
  };

  CircuitBoard.prototype.updateLEDs = function(pipelineStep, executionStep) {
    if (this.isHalted) {
      return;
    }
    if (!this.areEffectsEnabled()) {
      $('.board-led').show();
    } else {
      $('.board-led').hide().stop(true, true);
    }
    $('.ledOn').removeClass('ledOn');
    this.ledOverlay.show().removeClass('fetch').removeClass('increment').removeClass('execute');
    switch (pipelineStep) {
      case 0:
        this.fetchLED.addClass('ledOn');
        this.ledOverlay.addClass('fetch');
        break;
      case 1:
        this.incrementLED.addClass('ledOn');
        this.ledOverlay.addClass('increment');
        break;
      case 2:
        this.executeLED.addClass('ledOn');
        this.ledOverlay.addClass('execute');
    }
    if (this.areEffectsEnabled()) {
      return $('.board-led').fadeIn('fast');
    }
  };

  CircuitBoard.prototype.formatValue = function(value) {
    return parseInt(value).toString(16).toUpperCase();
  };

  CircuitBoard.prototype.togglePower = function() {
    var _this = this;
    if (!this.isReady) {
      return;
    }
    if (this.isOn) {
      this.background.removeClass('on');
      this.isOn = false;
      this.chipBox.fadeOut();
      $('.ledOn').removeClass('ledOn');
      this.ledOverlay.hide();
      this.chipBox.fadeOut();
      this.playSound(this.audio.powerdown);
      this.output.fadeOut();
      return setTimeout((function() {
        return _this.bgSound.remove();
      }), 500);
    } else {
      this.background.addClass('on');
      this.isOn = true;
      this.chipBox.fadeIn();
      this.reset();
      this.playSound(this.audio.powerup);
      this.output.fadeIn();
      return setTimeout((function() {
        return _this.backgroundSound(_this.audio.hum);
      }), 500);
    }
  };

  CircuitBoard.prototype.reset = function() {
    if (this.isOn) {
      this.isHalted = false;
      this.haltedStatus.text('');
      this.clearHighlights();
      return this.chip.reset();
    }
  };

  CircuitBoard.prototype.run = function() {
    if (this.isOn && !this.isHalted) {
      this.clearHighlights();
      return this.chip.run();
    }
  };

  CircuitBoard.prototype.speedRun = function() {
    if (this.isOn && !this.isHalted) {
      this.clearHighlights();
      return this.chip.speedRun();
    }
  };

  CircuitBoard.prototype.step = function() {
    if (this.isOn && !this.isHalted) {
      return this.chip.step();
    }
  };

  CircuitBoard.prototype.halt = function() {
    var flash, self;
    this.isHalted = true;
    this.haltedStatus.text('Halted');
    $('.ledOn').removeClass('ledOn');
    this.ledOverlay.hide();
    $('.board-led').hide().stop(true, true);
    this.fetchLED.addClass('ledOn');
    this.incrementLED.addClass('ledOn');
    this.executeLED.addClass('ledOn');
    self = this;
    flash = function(led) {
      return $(led).fadeOut('slow', function() {
        if (self.isHalted) {
          return $(this).fadeIn('fast', function() {
            return flash($(this));
          });
        }
      });
    };
    return $('.board-led').fadeIn('fast', function() {
      return flash(this);
    });
  };

  CircuitBoard.prototype.ringBell = function() {
    var _this = this;
    if (this.areEffectsEnabled()) {
      this.playSound(this.audio.ding);
    }
    this.bell.stop(true, true);
    this.bell.addClass('ringing');
    return this.bell.fadeOut(800, function() {
      _this.bell.removeClass('ringing');
      return _this.bell.show();
    });
  };

  CircuitBoard.prototype.buildMemoryTable = function(pageNum, numRows, numCols, properties) {
    var $cell, $cellInput, $row, $table, cellNum, changeMemory, hoverCell, i, j, unhoverCell, _i, _j, _ref,
      _this = this;
    changeMemory = function(address, value) {
      return _this.chip.updateMemory(address, parseInt(value, 16));
    };
    hoverCell = function(cell) {
      var address, instruction;
      address = (cell.attr('id')).replace('memory-', '');
      instruction = properties.instructions[parseInt(cell.val(), 16)];
      if (instruction != null) {
        return _this.instructionHelp.text('[' + address + '] ' + cell.val() + ': ' + instruction.description);
      }
    };
    unhoverCell = function(cell) {
      return _this.instructionHelp.text('');
    };
    $table = $('<table class="table table-bordered table-striped table-hover board-memory-table">');
    $table.attr('id', 'memory-table-page-' + pageNum);
    cellNum = (numRows * numCols) * pageNum;
    for (i = _i = 0; 0 <= numRows ? _i < numRows : _i > numRows; i = 0 <= numRows ? ++_i : --_i) {
      $row = $('<tr>');
      for (j = _j = 0, _ref = numCols + 1; 0 <= _ref ? _j < _ref : _j > _ref; j = 0 <= _ref ? ++_j : --_j) {
        if (j === 0) {
          $cell = $('<th>');
          $cell.text('0x' + this.formatValue(cellNum));
        } else {
          $cell = $('<td>');
          if (cellNum < properties.numMemoryAddresses) {
            $cellInput = $('<input type="text" class="board-memory-input">');
            $cellInput.attr('maxlength', properties.memoryBitSize / 4);
            $cellInput.attr('id', 'memory-' + cellNum);
            $cellInput.change(function() {
              var address, cell, value;
              cell = $(this);
              address = (cell.attr('id')).replace('memory-', '');
              value = cell.val();
              return changeMemory(address, value);
            });
            $cellInput.click(function() {
              return $(this).select();
            });
            $cell.append($cellInput);
            /*
            						$cell.tooltip {
            							placement: 'left'
            							title: ""+cellNum
            						}
            */

            $cellInput.mouseout(function() {
              return unhoverCell($(this));
            });
            $cellInput.bind('mouseover keyup change', function() {
              return hoverCell($(this));
            });
          }
          cellNum += 1;
        }
        $row.append($cell);
      }
      $table.append($row);
    }
    return $table;
  };

  CircuitBoard.prototype.buildMemoryPages = function(properties, $memoryContainer) {
    var $pageLink, $pagination, $paginationList, $table, clickPagination, numAddresses, numCols, numRows, pageNum, pages, _i,
      _this = this;
    clickPagination = function(link) {
      var page;
      page = $(link).data('page');
      _this.hiddenTables.append(_this.visibleTable);
      _this.visibleTable = $('#memory-table-page-' + page);
      _this.tableBox.html(_this.visibleTable);
      $('.board-memory-pagination').find('.active').removeClass('active');
      $('#memory-page-' + page).parent('li').addClass('active');
      return false;
    };
    numAddresses = properties.numMemoryAddresses;
    numRows = Math.min(8, Math.floor(Math.sqrt(numAddresses)));
    numCols = Math.min(8, numAddresses / numRows);
    pages = numAddresses / (numRows * numCols);
    this.visibleTable = this.buildMemoryTable(0, numRows, numCols, properties);
    this.hiddenTables = $('<div class="hide">');
    $paginationList = $('<ul>');
    $pagination = $('<center>').append($('<div class="well board-memory-pagination">').append($paginationList));
    $pageLink = $('<a href="#">').text(0);
    $pageLink.attr('id', 'memory-page-' + 0);
    $pageLink.data('page', 0);
    $pageLink.click(function() {
      return clickPagination(this);
    });
    $paginationList.append($('<li class="active">').append($pageLink));
    for (pageNum = _i = 1; 1 <= pages ? _i < pages : _i > pages; pageNum = 1 <= pages ? ++_i : --_i) {
      $table = this.buildMemoryTable(pageNum, numRows, numCols, properties);
      this.hiddenTables.append($table);
      $pageLink = $('<a href="#">').text(pageNum);
      $pageLink.attr('id', 'memory-page-' + pageNum);
      $pageLink.data('page', pageNum);
      $pageLink.click(function() {
        return clickPagination(this);
      });
      $paginationList.append($('<li>').append($pageLink));
    }
    this.tableBox = $('<center>');
    this.tableBox.html(this.visibleTable);
    $memoryContainer.append(this.tableBox);
    if (pages > 1) {
      return $memoryContainer.append($pagination);
    }
  };

  CircuitBoard.prototype.buildInspector = function(properties) {
    var $cell, $groupA, $groupB, $groupC, $headers, $memoryContainer, $outputBtn, $refTable, $reference, $registerContainer, $registerInput, $registers, $resetBtn, $restoreBtn, $saveBtn, $sliderBox, $speedRunButton, $table, $uploadBtn, changeRegister, hoverRegister, i, instruction, maxRowLength, registerName, row, rowLength, unhoverRegister, _i, _j, _k, _len, _len1, _ref, _ref1, _ref2,
      _this = this;
    this.properties = properties;
    changeRegister = function(name, value) {
      return _this.chip.updateRegister(name, parseInt(value, 16));
    };
    hoverRegister = function(regInput) {
      var instruction, val;
      if ((regInput.attr('id')) === 'register-IP') {
        val = parseInt(regInput.val(), 16);
        $('#memory-' + val).addClass('increment-highlight');
        return _this.instructionHelp.text('Instruction Pointer at Address: ' + val + ' (0x' + val.toString(16).toUpperCase() + ')');
      } else if ((regInput.attr('id')) === 'register-IS') {
        instruction = _this.properties.instructions[parseInt(regInput.val(), 16)];
        if (instruction != null) {
          return _this.instructionHelp.text(regInput.val() + ': ' + instruction.description);
        }
      }
    };
    unhoverRegister = function(regInput) {
      $('.board-memory-input').removeClass('increment-highlight');
      return _this.instructionHelp.text('');
    };
    $refTable = $('<table class="table table-bordered table-hover">');
    $reference = $('<div class="board-reference">').append($('<h4>').text(properties.name + ' Instruction Set')).append($refTable);
    $refTable.append($('<tr>').append($('<th>').text('#')).append($('<th>').text('Hex')).append($('<th>').text('Inc')).append($('<th>').text('Description')));
    i = 0;
    _ref = this.properties.instructions;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      instruction = _ref[_i];
      row = $('<tr>');
      row.append($('<td>').text(i));
      row.append($('<td>').text('0x' + i.toString(16).toUpperCase()));
      row.append($('<td>').text(instruction.ipIncrement));
      row.append($('<td>').text(instruction.description));
      $refTable.append(row);
      i += 1;
    }
    this.instructionReference.html($reference);
    this.chipName.append($('<span>').text(properties.name));
    this.toolbar = $('<div class="btn-toolbar board-toolbar">');
    $sliderBox = $('<div class="board-speed-slider" style="margin-top: 12px; margin-right: 12px; float:right; width: 120px;">');
    this.slider = $('<div>').slider({
      value: 500 - this.chip.runSpeed,
      max: 500,
      min: 10,
      change: function(event, ui) {
        var value;
        value = 500 - ui.value;
        _this.chip.runSpeed = value;
        if (value > 200) {
          return _this.effectsEnabled = true;
        } else {
          return _this.effectsEnabled = false;
        }
      }
    });
    $sliderBox.append(this.slider);
    $groupA = $('<div class="btn-group">');
    $groupB = $('<div class="btn-group">');
    $groupC = $('<div class="btn-group">');
    $saveBtn = $('<div class="btn btn-small">').html($('<i class="icon-download">')).tooltip({
      title: 'Save Current State',
      placement: 'bottom'
    });
    $saveBtn.click(function() {
      return _this.savedState = _this.currentState;
    });
    $restoreBtn = $('<div class="btn btn-small">').html($('<i class="icon-upload">')).tooltip({
      title: 'Restore State',
      placement: 'bottom'
    });
    $restoreBtn.click(function() {
      if (_this.savedState != null) {
        return _this.chip.setState(_this.savedState);
      }
    });
    $uploadBtn = $('<div class="btn btn-small">').html($('<i class="icon-download-alt"> ')).tooltip({
      title: 'Upload Program',
      placement: 'bottom'
    });
    $uploadBtn.click(function() {
      _this.editor.dialog("open");
      $('#code-tab').tab('show');
      return _this.editor.find('textarea').focus();
    });
    $resetBtn = $('<div class="btn btn-small">').html($('<i class="icon-off">')).tooltip({
      title: 'Reset',
      placement: 'bottom'
    });
    $resetBtn.click(function() {
      return _this.reset();
    });
    $speedRunButton = $('<span class="btn btn-small">').html($('<i class="icon-forward">')).tooltip({
      title: 'Fast Run',
      placement: 'bottom'
    });
    $speedRunButton.click(function() {
      return _this.speedRun();
    });
    $outputBtn = $('<div class="btn btn-small">').html($('<i class="icon-file">')).tooltip({
      title: 'Full Output',
      placement: 'bottom'
    });
    $outputBtn.click(function() {
      return document.location = 'data:Application/octet-stream,' + encodeURIComponent(_this.currentState.output);
    });
    $groupA.append($uploadBtn);
    $groupB.append($saveBtn).append($restoreBtn).append($resetBtn);
    $groupC.append($speedRunButton);
    this.toolbar.append($groupA).append($groupB).append($groupC);
    this.chipBox.append($sliderBox);
    this.chipBox.append(this.toolbar);
    $memoryContainer = $('<div class="board-memory-container">');
    this.buildMemoryPages(properties, $memoryContainer);
    this.chipBox.append($memoryContainer);
    $registerContainer = $('<div class="board-register-container">');
    $table = $('<table class="table table-bordered table-striped board-register-table">');
    $headers = $('<tr>');
    $registers = $('<tr>');
    maxRowLength = 6;
    maxRowLength = Math.min(maxRowLength, properties.registerNames.length);
    rowLength = 0;
    _ref1 = properties.registerNames;
    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      registerName = _ref1[_j];
      if (rowLength >= maxRowLength) {
        rowLength = 0;
        $table.append($headers);
        $table.append($registers);
        $headers = $('<tr>');
        $registers = $('<tr>');
      }
      $headers.append($('<th>').text(registerName));
      $cell = $('<td>');
      $registerInput = $('<input type="text" class="board-register-input">');
      $registerInput.attr('maxlength', properties.registerBitSize / 4);
      $registerInput.attr('id', 'register-' + registerName);
      $registerInput.change(function() {
        var cell, name, value;
        cell = $(this);
        name = (cell.attr('id')).replace('register-', '');
        value = cell.val();
        return changeRegister(name, value);
      });
      $registerInput.mouseover(function() {
        return hoverRegister($(this));
      });
      $registerInput.mouseout(function() {
        return unhoverRegister($(this));
      });
      $registerInput.click(function() {
        return $(this).select();
      });
      $cell.append($registerInput);
      $registers.append($cell);
      rowLength += 1;
    }
    if (rowLength !== 0) {
      for (i = _k = 0, _ref2 = maxRowLength - rowLength; 0 <= _ref2 ? _k < _ref2 : _k > _ref2; i = 0 <= _ref2 ? ++_k : --_k) {
        $headers.append($('<td>'));
        $registers.append($('<td>'));
      }
      $table.append($headers);
      $table.append($registers);
    }
    $registerContainer.append($('<center>').append($table));
    this.haltedStatus = $('<span class="board-halted-status">');
    this.cycleLabel = $('<span class="board-cycle-status">');
    this.cycleLabel.text('0 execution cycles');
    this.instructionHelp = $('<div class="well board-instruction-help">');
    this.status = $('<div class="board-status">');
    this.status.append(this.cycleLabel).append(this.haltedStatus);
    this.chipBox.append($registerContainer);
    this.chipBox.append(this.instructionHelp);
    this.chipBox.append(this.status);
    return this.chipBox.append(this.hiddenTables);
  };

  CircuitBoard.prototype.uploadCode = function(code) {
    var instruction, instructions, memory, val, _i, _len;
    if (code == null) {
      code = null;
    }
    if (!(code != null)) {
      code = this.codeBox.val();
    }
    instructions = (code.replace(/\s+/g, ',')).split(',');
    memory = [];
    for (_i = 0, _len = instructions.length; _i < _len; _i++) {
      instruction = instructions[_i];
      instruction = instruction.replace(/\s+/g, '');
      if (this.hexOption.prop('checked')) {
        val = parseInt(instruction, 16);
      } else {
        val = parseInt(instruction);
      }
      if (instruction !== '' && !(isNaN(val))) {
        memory.push(val);
      }
    }
    this.currentState = {
      memory: memory,
      registers: [],
      isHalted: false,
      output: '',
      numBellRings: 0,
      pipelineStep: 0,
      executionStep: 0
    };
    return this.chip.setState(this.currentState);
  };

  CircuitBoard.prototype.build = function() {
    var $codeTab, $editorTab, $refTab, $tabContent, $tabs, uploadCode,
      _this = this;
    this.board = $(this.selector);
    $codeTab = $('<li class="active"><a href="#code" id="code-tab" class="editor-tab">Code</a></li>');
    $refTab = $('<li><a href="#reference" class="editor-tab">Reference</a></li>');
    $tabs = $('<ul class="nav nav-tabs">').append($codeTab).append($refTab);
    this.codeBox = $('<textarea class="board-code">');
    this.hexOption = $('<input name="use-hex" type="checkbox">');
    this.editor = $('<div class="board-editor" title="Upload Code">');
    $editorTab = $('<div class="tab-pane active" id="code">');
    $editorTab.append(this.codeBox).append('<br/>').append($('<label for="use-hex">').append(this.hexOption).append($('<span>').text(' Only Use Hexadecimal')));
    this.instructionReference = $('<div class="tab-pane" id="reference">');
    $tabContent = $('<div class="tab-content">');
    $tabContent.append($editorTab).append(this.instructionReference);
    this.editor.append($tabs);
    this.editor.append($tabContent);
    this.background = $('<div class="board-bg">');
    this.powerSwitch = $('<div class="board-power">');
    this.bell = $('<div class="board-bell">');
    this.bellOverlay = $('<div class="board-bell-overlay">');
    this.fetchLED = $('<div class="board-fetch board-led">');
    this.incrementLED = $('<div class="board-increment board-led">');
    this.executeLED = $('<div class="board-execute board-led">');
    this.output = $('<div class="board-output-lcd">');
    this.ledOverlay = $('<div class="board-ledOverlay">');
    this.resetButton = $('<div class="board-reset">');
    this.runButton = $('<div class="board-run">');
    this.stepButton = $('<div class="board-step">');
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
      title: 'Reset to zero'
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
      if (_this.isOn) {
        return _this.chipBox.fadeToggle();
      }
    });
    this.board.html(this.background);
    this.board.append(this.editor);
    this.background.append(this.powerSwitch).append(this.bell).append(this.bellOverlay).append(this.fetchLED).append(this.incrementLED).append(this.executeLED).append(this.resetButton).append(this.runButton).append(this.stepButton).append(this.chipName).append(this.output).append(this.ledOverlay).append(this.chipBox);
    uploadCode = function() {
      return _this.uploadCode();
    };
    this.editor.dialog({
      autoOpen: false,
      width: 540,
      buttons: {
        "Close": function() {
          return $(this).dialog("close");
        },
        "Upload": function() {
          uploadCode();
          return $(this).dialog("close");
        }
      },
      position: [20, 13]
    });
    $('button').addClass('btn');
    return $('.editor-tab').click(function() {
      $(this).tab('show');
      return false;
    });
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
    circuitBoard = new CircuitBoard(element, options.definition, options.startingState, options.audio);
    return $(element).data('spud', circuitBoard);
  }
});
