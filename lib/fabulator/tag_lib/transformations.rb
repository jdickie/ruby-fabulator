require 'xml/libxml'
require 'libxslt'

module Fabulator
  class TagLib
    class Transformations

      def initialize
        @formats = { }
      end

      def html(&block)
        @formats[:html] ||= Fabulator::TagLib::Format.new
        @formats[:html].instance_eval &block
      end

      def transform(fmt, doc, opts = { })
        if !@formats[fmt.to_sym].nil?
          @formats[fmt.to_sym].transform(doc, opts)
        else
          doc
        end
      end

      def get_root_namespaces(fmt)
        if !@formats[fmt.to_sym].nil?
          @formats[fmt.to_sym].get_root_namespaces
        else
          []
        end
      end
    end

    class Format
      def initialize
      end

      def transform(doc, opts)
        if !@xslt.nil?
          @xslt.apply(doc, opts) 
        else
          doc
        end
      end

      def xslt_from_file(fpath)
        @xslt_file = fpath
        @xslt_doc = LibXML::XML::Document.file(@xslt_file)
        @xslt = LibXSLT::XSLT::Stylesheet.new(@xslt_doc)
      end

      def get_root_namespaces
        if !@xslt_doc.nil?
          # extract namespace declarations from root element
          ret = [ ]
          @xslt_doc.root.namespaces.each { |ns|
            ret << ns.href
          }
          ret
        else
          []
        end
      end
    end
  end
end
