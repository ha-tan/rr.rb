#!/usr/bin/env ruby
# -*- compile-command: "ruby rr.rb" -*-

require "bigdecimal"
require "bigdecimal/math"
require 'readline'

class RPCalc
  class QuitException < Exception; end
  class MessageException < Exception; end

  def initialize
    @stack = []
    @outmode = :dec
  end
  
  def calc_op(n, s, math_f = false, &block)
    raise 'stack empty' if @stack.size < n
    ops = []
    case n
    when 1
      ops[0] = @stack.pop
    when 2
      ops[1] = @stack.pop
      ops[0] = @stack.pop
    end
    ops = block.call(ops) if block
    ans = if math_f
            BigDecimal.new(Math.send(s, *ops).to_s)
          else
            ops[0].send(s, *ops[1 .. -1])
          end
    if ans.class == Array
      ans.map {|a| @stack.push(a) }
    else
      @stack.push(ans)
    end
  end
  private :calc_op
  
  def calc(line)
    @quit_f = false
    @help_f = false

    re = /(?:
           -?\d+\.\d+|
           [\da-fA-F]+h|
           [0-7]+o|
           -?\d+|
           \*\*|
           [\+\-\*\/%]|
           \w+
         )/x
    line.scan(re) do |s|
      case s
      when /\A[\da-zA-Z]+h\z/
        @stack << BigDecimal.new(s.hex.to_s)
      when /\A[0-7]+o\z/
        @stack << BigDecimal.new(s.oct.to_s)
      when /\A-?\d+/
        @stack << BigDecimal.new(s)
      when '+', '-', '*', '/', '%', '**'
        calc_op(2, s) do |ops|
          op[1] = ops[1].to_i if s == '**'
          ops
        end
      when *%w|fix frac floor ceil round truncate abs exponent sqrt|
        calc_op(1, s)
      when 'divmod'
        calc_op(2, s)
      when *%w|acos asin atan acosh asinh atanh cos sin tan cosh sinh tanh erf erfc exp frexp log log10|
        calc_op(1, s, true)
      when *%w|atan2 hypot ldexp|
        calc_op(2, s, true)
      when 'e'
        @stack.push(BigDecimal.new(Math::E.to_s))
      when 'pi'
        @stack.push(BigDecimal.new(Math::PI.to_s))
      when 'c' # clear
        @stack.clear
      when 'n' # pop
        @stack.pop
      when 'd' # dup
        raise 'stack empty' if @stack.size < 1
        op2 = @stack.pop
        @stack.push(op2)
        @stack.push(op2)
      when 'r' # replace
        raise 'stack empty' if @stack.size < 2
        op2 = @stack.pop
        op1 = @stack.pop
        @stack.push(op2)
        @stack.push(op1)
      when 'x' # print hex
        @outmode = (@outmode == :hex) ? :dec : :hex
      when 'o' # print oct
        @outmode = (@outmode == :oct) ? :dec : :oct
      when 'q' # quit
        raise QuitException.new
      when 'h' # help
        raise MessageException.new(help_message)
      when 'v' # version
        raise MessageException.new(version_message)
      else
        raise 'unknown function or operation'
      end
    end

    return @stack.reverse.map do |n| 
      case @outmode
      when :dec; n.to_s('F')
      when :hex; "%xh" % n.to_i
      when :oct; "%oo" % n.to_i
      end
    end
  end

  def help_message
    return <<EOF
number format:
  123, 0.1, 100h, 100o
function:
  + - * / % **
  fix frac floor ceil round truncate abs exponent sqrt divmod
  acos asin atan acosh asinh atanh cos sin tan cosh sinh tanh 
  erf erfc exp frexp log log10
  atan2 hypot ldexp
constatnt:
  e pi
operation:
  c ... clear stack
  n ... pop stack
  d ... duplicate top on stack
  r ... replace top 2 on stack
  x ... print hex
  o ... print oct
  q ... quit
  h ... print this message
  v ... print version
EOF
  end

  def version_message
    return 'rr.rb v1.0'
  end
end

def do_calc(calc, s)
  xs = calc.calc(s)
  puts '[' + xs.join(', ') + ']'
end

calc = RPCalc.new
do_calc(calc, ARGV.join(' '))
while line = Readline.readline('> ', true)
  begin
    do_calc(calc, line)
  rescue RPCalc::QuitException
    break
  rescue RPCalc::MessageException => ex
    puts ex.message
  rescue => ex
    puts ex.message
  end
end
