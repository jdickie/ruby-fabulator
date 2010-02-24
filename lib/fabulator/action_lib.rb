module Fabulator
  module ActionLib
    @@action_descriptions = {}
    @@function_descriptions = {}
    @@namespaces = {}
    @@attributes = [ ]
    @@last_description = nil
    @@types = { }

    def self.last_description
      @@last_description
    end
    def self.namespaces
      @@namespaces
    end
    def self.action_descriptions
      @@action_descriptions
    end
    def self.function_description
      @@function_description
    end
    def self.attributes
      @@attributes
    end
    def self.types
      @@types
    end

    def self.last_description=(x)
      @@last_description = x
    end
    def self.namespaces=(x)
      @@namespaces = x
    end
    def self.action_descriptions=(x)
      @@action_descriptions = x
    end
    def self.function_description=(x)
      @@function_description = x
    end
    def self.attributes=(x)
      @@attributes = x
    end
    def self.types=(x)
      @@types = x
    end

    def self.included(base)
      base.extend(ClassMethods)
      base.module_eval do
        def self.included(new_base)
          super
          new_base.action_descriptions.merge! self.action_descriptions
          new_base.function_descriptions.merge! self.function_descriptions
          new_base.types.merge! self.types
        end
      end
    end

    def self.compile_actions(xml, c_attrs)
      actions = [ ]
      attrs = self.collect_attributes(c_attrs, xml)
      xml.each_element do |e|
        ns = e.namespaces.namespace.href
        next unless Fabulator::ActionLib.namespaces.include?(ns)
        actions << Fabulator::ActionLib.namespaces[ns].compile_action(e, attrs) # rescue nil)
      end
      actions = actions - [ nil ]
      return actions
    end

    def self.collect_attributes(attrs, xml)
      ret = { }
      attrs.each_pair do |k,v|
        ret[k] = { }
        ret[k].merge!(v)
      end

      parser = Fabulator::Expr::Parser.new

      @@attributes.each do |a|
        v = xml.attributes.get_attribute_ns(a[0], a[1])
        if !v.nil?
          ret[a[0]] = {} if ret[a[0]].nil?
          v = v.value
          if !a[2][:expression] && v =~ /^\{(.*)\}$/
            v = (parser.parse($1) rescue nil)
          else
            v = Fabulator::Expr::Literal.new(v)
          end
          ret[a[0]][a[1]] = v
        end
      end
      ret
    end

    def self.get_attribute(ns, attr, attrs)
      return nil if attrs.nil? || attrs[ns].nil? || attrs[ns].empty? || attrs[ns][attr].nil?
      return attrs[ns][attr]
    end

    def self.get_local_attr(xml, ns, attr, options = {})
      v = (xml.attributes.get_attribute_ns(ns, attr).value rescue nil)
      if v.nil? && !options[:default].nil?
        v = options[:default]
      end

      if !v.nil?
        e = nil
        if !options[:eval] 
          if v =~ /^\{(.*)\}$/
            e = $1
          end
        else
          e = v
        end
        if !e.nil?
          p = Fabulator::Expr::Parser.new
          v = p.parse(e)
        else
          v = Fabulator::Expr::Literal.new(v, [ FAB_NS, 'string' ])
        end
      end
      v
    end

    def self.get_select(xml, default)
      self.get_local_attr(xml, FAB_NS, 'select', { :eval => true, :default => default })
    end
 
    def compile_action(e, r)
      #Rails.logger.info("compile_action called with #{YAML::dump(r)}")
      if self.class.method_defined? "action:#{e.name}"
        send "action:#{e.name}", e, Fabulator::ActionLib.collect_attributes(r, e)
      end
    end

    def self.unify_types(ts)
      # we want to find a single type that can represent all of the information
      # contained in the types in ts
      #
      # for example, an int and a real would unify to a real
      #   or, an int and a rational would unify to a rational
      #
      # worst case: unify to a string if all types can be represented
      #    as strings
    end

    def run_function(context, nom, args)
      ret = send "fctn:#{nom}", args
      ret = [ ret ] unless ret.is_a?(Array)
      ret = ret.collect{ |r| 
        if r.is_a?(Fabulator::Expr::Context) 
          r 
        elsif r.is_a?(Hash)
          rr = [ ]
          r.each_pair do |k,v|
            rrr = context.anon_node(v)
            rrr.name = k
            rr << rrr
          end
          rr
        else
          context.anon_node(r)
        end
      }
      ret.flatten
    end

    def action_descriptions(hash=nil)
      self.class.action_descriptions hash
    end

    def function_descriptions(hash=nil)
      self.class.function_descriptions hash
    end
  
    module ClassMethods
      def inherited(subclass)
        subclass.action_descriptions.reverse_merge! self.action_descriptions
        super
      end
      
      def action_descriptions(hash = nil)
        Fabulator::ActionLib.action_descriptions[self.name] ||= (hash ||{})
      end
    
      def register_namespace(ns)
        Fabulator::ActionLib.namespaces[ns] = self.new
      end

      def register_attribute(a, options = {})
        ns = nil
        Fabulator::ActionLib.namespaces.each_pair do |k,v|
          if v.is_a?(self)
            ns = k
          end
        end
        Fabulator::ActionLib.attributes << [ ns, a, options ]
      end

      def register_type(nom, options={})
        ns = nil
        Fabulator::ActionLib.namespaces.each_pair do |k,v|
          if v.is_a?(self)
            ns = k
          end
        end
        Fabulator::ActionLib.types[ns] ||= {}
        Fabulator::ActionLib.types[ns][nom] = options
      end

      def namespaces
        Fabulator::ActionLib.namespaces
      end
  
      def desc(text)
        Fabulator::ActionLib.last_description = RedCloth.new(Util.strip_leading_whitespace(text)).to_html
      end
      
      def action(name, klass = nil, &block)
        self.action_descriptions[name] = Fabulator::ActionLib.last_description if Fabulator::ActionLib.last_description
        Fabulator::ActionLib.last_description = nil
        if block
          define_method("action:#{name}", &block)
        elsif !klass.nil?
          action(name) { |e,r|
            return klass.new.compile_xml(e,r)
          }
        end
      end

      def function(name, &block)
        self.function_descriptions[name] = Fabulator::ActionLib.last_description if Fabulator::ActionLib.last_description
        Fabulator::ActionLib.last_description = nil
        define_method("fctn:#{name}", &block)
      end

      def compile_actions(xml, rdf_model)
        actions = [ ]
        xml.each_element do |e|
          ns = e.namespaces.namespace.href
          #Rails.logger.info("Compiling <#{ns}><#{e.name}>")
          next unless Fabulator::ActionLib.namespaces.include?(ns)
          actions << (Fabulator::ActionLib.namespaces[ns].compile_action(e, rdf_model) rescue nil)
          #Rails.logger.info("compile_actions: #{actions}")
        end
        #Rails.logger.info("compile_actions: #{actions}")
        actions = actions - [ nil ]
        #Rails.logger.info("compile_actions returning: #{actions}")
        return actions
      end
  
    end
     
    module Util
      def self.strip_leading_whitespace(text)
        text = text.dup
        text.gsub!("\t", "  ")
        lines = text.split("\n")
        leading = lines.map do |line|
          unless line =~ /^\s*$/
             line.match(/^(\s*)/)[0].length
          else
            nil
          end
        end.compact.min
        lines.inject([]) {|ary, line| ary << line.sub(/^[ ]{#{leading}}/, "")}.join("\n")
      end      
    end
  end
end
