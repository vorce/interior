defmodule Basic.Foo do
  def no_bar_violation do
    Basic.Bar.hello!()
  end

  def bar_violation do
    Basic.Bar.Private.Hello.world()
  end

  def no_baz_violation do
    Basic.Baz.heh()
  end

  def baz_violation do
    Basic.Baz.Inner.foo()
  end

  def no_qux_violation do
    Basic.Qux.Meh.allowed()
  end

  def qux_violation do
    Basic.Qux.Nah.not_allowed()
  end
end
