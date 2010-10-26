module Fabulator
  module Expr
    class StatementList
      def initialize
        @statements = [ ]
        @ensures = [ ]
        @catches = [ ]
        @context = nil
      end

      def use_context(c)
        @context = c
      end

      def add_statement(s)
        @statements << s if !s.nil?
      end

      def add_ensure(s)
        @ensures << s
      end

      def add_catch(s)
        @catches << s
      end

      def is_noop?
        @statements.empty? && @ensures.empty?
      end

      def empty?
        @statements.empty? && @ensures.empty?
      end

      def run(context, autovivify = false)
        if !@context.nil?
          context = @context
        end
        result = [ ]
        begin
          if !@statements.nil?
            (@statements - [nil]).each do |s| 
              result = s.run(context, autovivify)
            end
          end
        rescue Fabulator::StateChangeException => e
          raise e
        rescue => e
          result = []
          caught = false
          ex = nil
          if e.is_a?(Fabulator::Expr::Exception) 
            ex = e.node
          else
            ex = context.root.anon_node(e.to_s, [ FAB_NS, 'string' ])
            ex.set_attribute('class', 'ruby.' + e.class.to_s.gsub(/::/, '.'))
          end
          if !@catches.nil?
            @catches.each do |s|
              if !s.nil? && s.run_test(ex)
                caught = true
                result = s.run(context.with_root(ex), autovivify)
              end
            end
          end

          raise e unless caught
        ensure
          if !@ensures.nil? && !@ensures.empty?
            @ensures.each do |s|
              s.run(context, autovivify) unless s.nil?
            end
          end
        end

        return result
      end
    end

    class WithExpr
      def initialize(e,w)
        @expr = e
        @with = w
      end

      def run(context, autovivify = false)
        result = @expr.run(context, autovivify)
        result.each do |r|
          @with.run(context.with_root(r), true)
        end
        result
      end
    end

    class ErrExpr
      def initialize(e,c)
        @expr = e
        @err_expr = c
      end

      def run(context, autovivify = false)
        result = []
        begin
          result = @expr.run(context, autovivify)
        rescue => e
          ctx = context.merge
          ctx.set_var('e', e)
          result = @err_expr.run(ctx)
        end
        result
      end
    end

    class DataSet
      def initialize(p,v)
        @path = p
        @value = v
      end

      def run(context, autovivify = false)
        context.set_value(@path, @value)
        [ context.root ]
      end
    end
  end
end

