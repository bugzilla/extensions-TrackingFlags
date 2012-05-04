/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * This Source Code Form is "Incompatible With Secondary Licenses", as
 * defined by the Mozilla Public License, v. 2.0. */

var Dom = YAHOO.util.Dom;
var Event = YAHOO.util.Event;

Event.onDOMReady(function() {
  try {
    Event.addListener('flag_name', 'blur', trim_value, Dom.get('flag_name'));
    Event.addListener('flag_desc', 'blur', trim_value, Dom.get('flag_desc'));
    Event.addListener('flag_sort', 'blur', int_value, Dom.get('flag_sort'));

    Event.addListener('product', 'change', function() {
      if (Dom.get('product').value == '')
        Dom.get('component').options.length = 0;
    });

    update_flag_values();
    update_flag_visibility();
  } catch(e) {
    console.error(e);
  }
});

// field

function inc_field(id, amount) {
  var el = Dom.get(id);
  el.value = el.value.match(/-?\d+/) * 1 + amount;
}

// values

function update_flag_values() {
  // update the values table from the flag_values global

  var tbl = Dom.get('flag_values');

  // remove current entries
  while (tbl.rows.length > 3) {
    tbl.deleteRow(2);
  }

  // add all entries

  for (var i = 0, l = flag_values.length; i < l; i++) {
    var value = flag_values[i];

    var row = tbl.insertRow(2 + i);
    var cell;

    // value
    cell = row.insertCell(0);
    var inputEl = document.createElement('input');
    inputEl.id = 'value_' + i;
    inputEl.type = 'text';
    inputEl.className = 'option_value';
    inputEl.value = value.value;
    Event.addListener(inputEl, 'blur', trim_value, inputEl);
    Event.addListener(inputEl, 'change', function(e, o) {
        flag_values[o.id.match(/\d+$/)].value = o.value;
      }, inputEl);
    cell.appendChild(inputEl);

    // setter
    cell = row.insertCell(1);
    var selectEl = document.createElement('select');
    selectEl.id = 'setter_' + i;
    var optionEl = document.createElement('option');
    optionEl.value = '';
    selectEl.appendChild(optionEl);
    for (var j = 0, m = groups.length; j < m; j++) {
      var group = groups[j];
      optionEl = document.createElement('option');
      optionEl.value = group.id;
      optionEl.innerHTML = YAHOO.lang.escapeHTML(group.name);
      optionEl.selected = group.id == value.setter_group_id;
      selectEl.appendChild(optionEl);
    }
    Event.addListener(selectEl, 'change', function(e, o) {
        flag_values[o.id.match(/\d+$/)].setter_group_id = o.value;
      }, selectEl);
    cell.appendChild(selectEl);

    // active
    cell = row.insertCell(2);
    inputEl = document.createElement('input');
    inputEl.id = 'active_' + i;
    inputEl.type = 'checkbox';
    inputEl.checked = value.is_active;
    Event.addListener(inputEl, 'change', function(e, o) {
        flag_values[o.id.match(/\d+$/)].is_active = o.checked;
      }, inputEl);
    cell.appendChild(inputEl);

    // actions
    cell = row.insertCell(3);
    cell.innerHTML = 
      '[ ' +
      (i == 0
        ? '<span class="txt_icon">&nbsp;</span>'
        : '<a class="txt_icon" href="#" onclick="value_move_up(' + i + ');return false">&Delta;</a>'
      ) +
      ' | ' +
      ( i == l - 1
        ? '<span class="txt_icon">&nbsp;</span>'
        : '<a class="txt_icon" href="#" onclick="value_move_down(' + i + ');return false">&nabla;</a>'
      ) +
      ' | <a href="#" onclick="remove_value(' + i + ');return false">Remove</a> ]';
  }
}

function value_move_up(idx) { 
  if (idx == 0)
    return;
  var tmp = flag_values[idx];
  flag_values[idx] = flag_values[idx - 1];
  flag_values[idx - 1] = tmp;
  update_flag_values();
}

function value_move_down(idx) {
  if (idx == flag_values.length - 1)
    return;
  var tmp = flag_values[idx];
  flag_values[idx] = flag_values[idx + 1];
  flag_values[idx + 1] = tmp;
  update_flag_values();
}

function add_value() {
  var value = new Object();
  value.id = 0;
  value.value = '';
  value.setter_group_id = '';
  value.is_active = true;
  var idx = flag_values.length;
  flag_values[idx] = value;
  update_flag_values();
  Dom.get('value_' + idx).focus();
}

function remove_value(idx) {
  flag_values.splice(idx, 1);
  update_flag_values();
}

function update_value(e, o) {
  var i = o.value.match(/\d+/);
  flag_values[i].value = o.value;
}

// visibility

function update_flag_visibility() {
  // update the visibility table from the flag_visibility global

  var tbl = Dom.get('flag_visibility');

  // remove current entries
  while (tbl.rows.length > 3) {
    tbl.deleteRow(2);
  }

  // add all entries

  for (var i = 0, l = flag_visibility.length; i < l; i++) {
    var visibility = flag_visibility[i];

    var row = tbl.insertRow(2 + i);
    var cell;

    // product
    cell = row.insertCell(0);
    cell.innerHTML = visibility.product;

    // component
    cell = row.insertCell(1);
    cell.innerHTML = visibility.component
      ? visibility.component
      : '<i>-- Any --</i>'; 

    // actions
    cell = row.insertCell(2);
    cell.innerHTML = '[ <a href="#" onclick="remove_visibility(' + i + ');return false">Remove</a> ]';
  }
}

function add_visibility() {
  var product = Dom.get('product').value;
  var component = Dom.get('component').value;
  if (!product) {
    alert('Please select a product.');
    return;
  }
  var visibility = new Object();
  visibility.id = 0;
  visibility.product = product;
  visibility.component = component;
  flag_visibility[flag_visibility.length] = visibility;
  update_flag_visibility();
}

function remove_visibility(idx) {
  flag_visibility.splice(idx, 1);
  update_flag_visibility();
}

// utils

function trim_value(e, o) {
  o.value = YAHOO.lang.trim(o.value);
}

function int_value(e, o) {
  o.value = o.value.match(/-?\d+/);
}

