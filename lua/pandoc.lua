local api = vim.api
local Job = require('plenary/job')

local M = {}

local function echom(msg)
  vim.cmd(string.format('echom "%s"', msg))
end

local function echoerr(msg)
  vim.cmd(string.format('echoerr "%s"', msg))
end

local function is_error_code(code, name)
  if code ~= 0 then
    echoerr(string.format('The job %s exited with a non-zero code', name))
    return true
  else
    return false
  end
end

local function on_stdout_factory(name)
  return vim.schedule_wrap(function(error, data)
    assert(not error, error)
    echom(string.format('Stdout of job %s: %s', name, data))
  end)
end

local function on_stderr_factory(name)
  return vim.schedule_wrap(function(error, data)
    assert(not error, error)
    echoerr(string.format('An error occurred from job %s: %s', name, data))
  end)
end

local function on_exit_factory(name)
  return vim.schedule_wrap(function(self, code, signal)
    if code ~= 0 then
      echoerr(string.format('The job %s exited with a non-zero code', name))
    end
  end)
end

function M.convert(opts)
  Job:new {
    command = 'pandoc',
    args = {opts.from, '-o', opts.to},
    on_stderr = on_stderr_factory('pandoc'),
    on_exit = vim.schedule_wrap(function(self, code, signal)
      if not is_error_code(code, name) then
        if opts.open then
          M.open('zathura', opts.to)
        end
      end
    end),
  }:start()
end

function M.tectonic(opts)
  Job:new {
    command = 'tectonic',
    args = {opts.from},
    on_stderr = on_stderr_factory('tectonic'),
    on_exit = vim.schedule_wrap(function(self, code, signal)
      if not is_error_code(code, 'tectonic') then
        if opts.open then
          print('opening')
          M.open('zathura', opts.to)
        end
      end
    end)
  }:start()
end

function M.convert_current_file(open)
  local extension = vim.fn.expand('%:e')
  local name = vim.fn.expand('%:p:r')
  local path = api.nvim_buf_get_name(0)

  if extension == 'md' then
    M.convert {from = path, to = name .. '.pdf', open = open}
  elseif extension == 'tex' then
    M.tectonic {from = path, to = name .. '.pdf', open = open}
  end
end

function M.open(with, path)
  Job:new {
    command = with,
    args = {path},
    on_stderr = on_stderr_factory(with),
    on_exit = on_exit_factory(with),
  }:start()
end

return M
