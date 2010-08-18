module Fabulator
  module Core
  class Group < Fabulator::Action
    attr_accessor :name, :params, :tags, :required_params

    namespace Fabulator::FAB_NS

    has_select

    def initialize
      @params = [ ]
      @constraints = [ ]
      @filters = [ ]
      @required_params = [ ]
      @tags = [ ]
    end

    def compile_xml(xml, context)
      super
      xml.each_element do |e|
        next unless e.namespaces.namespace.href == FAB_NS

        case e.name
          when 'param':
            v = Parameter.new.compile_xml(e,@context)
            @params << v
            @required_params = @required_params + v.names if v.required?
          when 'group':
            v = Group.new.compile_xml(e,@context)
            @params << v
            @required_params = @required_params + v.required_params.collect{ |n| (@name + '/' + n).gsub(/\/+/, '/') }
          when 'constraint':
            @constraints << Constraint.new.compile_xml(e,@context)
          when 'filter':
            @filters << Filter.new.compile_xml(e,@context)
        end
      end
      self
    end

    def apply_filters(context)
      filtered = [ ]
 
      @context.with(context) do |ctx|

        self.get_context(ctx).each do |root|
          @params.each do |param|
            @filters.each do |f|
              filtered = filtered + f.apply_filter(ctx.with_root(root))
            end
            filtered = filtered + param.apply_filters(ctx.with_root(root))
          end
        end
      end
      filtered.uniq
    end

    def apply_constraints(context)
      res = { :missing => [], :invalid => [], :valid => [], :messages => [] }
      passed = [ ]
      failed = [ ]
      @context.with(context) do |ctx|
        self.get_context(ctx).each do |root|
          @params.each do |param|
            @constraints.each do |c|
              r = c.test_constraint(ctx.with_root(root))
              passed += r[0]
              failed += r[1]
            end
            p_res = param.apply_constraints(ctx.with_root(root))
            res[:messages] += p_res[:messages]
            failed += p_res[:invalid]
            passed += p_res[:valid]
            res[:missing] += p_res[:missing]
          end
        end
      end
      res[:invalid] = failed.uniq
      res[:valid] = (passed - failed).uniq
      res[:messages].uniq!
      res[:missing] = (res[:missing] - passed).uniq
      res
    end


    def get_context(context)
      return [ context.root ] if @select.nil?
      ret = [ ]
      context.in_context do |ctx|
        ret = @select.run(ctx)
      end
      ret
    end
  end
  end
end
