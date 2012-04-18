###
#
# Dispatcher for "home" commands
#  and active record initializer
#
###

# Gems for DB connectivity
require 'sqlite3'
require 'active_record'

# Active Records
current_dir = File.expand_path(File.dirname(__FILE__))
require "#{current_dir}/../../../../../models/transform"
require "#{current_dir}/../../../../../models/project"
require "#{current_dir}/../../../../../models/section"
require "#{current_dir}/../../../../../models/section_descriptor"
require "#{current_dir}/../../../../../models/entity"
require "#{current_dir}/../../../../../models/entity_type"
require "#{current_dir}/../../../../../models/entity_type_field"
require "#{current_dir}/../../../../../models/entity_field"
require "#{current_dir}/../../../../../models/link"
require "#{current_dir}/../../../../../models/link_type"
require "#{current_dir}/../../../../../models/link_type_field"
require "#{current_dir}/../../../../../models/link_field"

require "#{current_dir}/graphviz_generator"

module Poortego
module Console
module CommandDispatcher

###
#
# Home Dispatcher Class
#
###
class HomeDispatcher
  
  # Inherit from CommandDispatcher
  include Poortego::Console::CommandDispatcher
  
  #
  # Constructor
  #
  def initialize(driver)
    super  
    
    begin
      # Load database config from yaml file
      current_dir = File.expand_path(File.dirname(__FILE__))
      config = YAML::load(IO.read("#{current_dir}/../../../../../../config/database.yml"))

      # Establish ActiveRecord Connection
      ActiveRecord::Base.establish_connection(config['development'])

      # Evaluate ActiveRecord models
      Dir["#{current_dir}/../../../../../models/*.rb"].each { |file|
        eval(IO.read(file), binding)
      }
    rescue Exception => e
      puts "Exception establishing activerecord connection"
      puts self.inspect
      puts e.message
    end
  end
  
  #
  # Set prompt
  #
  def set_prompt
     type = driver.interface.working_values["Current Selection Type"]
     if (type == 'none')
       driver.update_prompt("")
     else
       name = driver.interface.working_values["Current Object"].title
       driver.update_prompt("(%bld%red"+type+":"+name+"%clr)")
     end
  end
  
  #
  # Supports these commands
  #
  def commands
    {
      "?"         => "Help menu",
      "exit"      => "Exit the console",
      "help"      => "Help menu",
      "back"      => "Return to previous dispatcher level",
      "connect"   => "Connect to DB (TODO: move constructor to allow on-the-fly DB connectivity)",
      "current"   => "Display the current state of things",
      "list"      => "List available objects (at current selection or parents)",
      "show"      => "Show a current object (at current selection or parents)",
      "select"    => "Select an object to manipulate",
      "create"    => "Create an object",
      "set"       => "Set field values for current object",
      "delete"    => "Delete an object",
      #"run"       => "Run transform/plugin in the current scope",  ## TODO
      "export"    => "Export data in the current scope to a specific format (e.g., graph)", ## TODO
    }
  end
  
  #
  # Dispatcher Name
  #
  def name
    "Home"
  end
  
  #
  # "Back" command logic
  #
  def cmd_back(*args)
    if (driver.dispatcher_stack.size > 1 and driver.current_dispatcher.name != 'Home')          
      driver.interface.move_back()
      driver.destack_dispatcher
      self.set_prompt()
    end
  end
  
  #
  # "Connect" command logic (TODO)
  #
  def cmd_connect(*args)
    ## TODO: add logic from Constructor
    cmd_connect_help
  end  
  
  #
  # "Connect" command help (TODO)
  #
  def cmd_connect_help(*args)
    print_status("TODO: a command to specify the DB connection.")
  end
  
  #
  # "Current" command logic
  #
  def cmd_current(*args)
    if (args.length > 0)
      cmd_current_help
    else
      # Display Dispatcher shared variables in shellinterface.rb
      tbl = Rex::Ui::Text::Table.new('Indent' => 4,
                                   'Columns' => ['Field',
                                                 'Value'   ])
      current_values = driver.interface.get_working_values()
      current_values.each do |key,value|
        tbl << ["#{key} :", "#{value}"]
      end
                                                 
      puts "\n" + tbl.to_s + "\n"
    end
  end
  
  #
  # "Current" command help
  #
  def cmd_current_help(*args)
    print_status("Command    : current")
    print_status("Description: displays the current system variables related to the state of things.")
    print_status("Usage      : 'current'")
  end
  
  #
  # "Show" command logic
  #
  #  show [[type] name]   (type/name optional)
  #
  def cmd_show(*args)
   
    #
    # TODO: add ability to show types/fields for links
    #
   
    # Default show type is the current selection
    show_type = driver.interface.working_values["Current Selection Type"]
    show_obj  = driver.interface.working_values["Current Object"] 
   
    # Argument driven type (optional) 
    if (args.length > 0)
      show_type = args[0]
    end
    
    # Argument driven name (optional)
    if (args.length > 1)
      show_name = args[1]
      case show_type
      when '-h', '-?'       
        cmd_show_help
        return
      when 'project'
        show_obj = Project.select(show_name)
      when 'section'
        show_obj = Section.select(driver.interface.working_values["Current Project"].id, 
                                  show_name)
      when 'transform'
        show_obj = Transform.select(show_name)
      when 'entity'
        show_obj = Entity.select(driver.interface.working_values["Current Project"].id, 
                                 driver.interface.working_values["Current Section"].id, 
                                 show_name)
      when 'link'
        show_obj = Link.select(driver.interface.working_values["Current Project"].id, 
                               driver.interface.working_values["Current Section"].id, 
                               show_name)
      when 'entity_type'
        show_obj = EntityType.select(show_name)
      when 'link_type'
        show_obj = LinkType.select(show_name)  
      else
        print_error("Invalid show type (#{show_type}).  Use -h if you need help.")
        return
      end              
    end
    if (args.length > 2)
      print_error("Ambiguous arguments.  Use -h if you need help.")
      return
    end
    
    # Populate table with the object's contents
    tbl = Rex::Ui::Text::Table.new('Indent' => 4,
                                   'Columns' => ["#{show_type} fields",
                                                 'values'   ])
    show_obj.attributes.each do |attr_name, attr_value|
      tbl << [attr_name, attr_value] 
      ## TODO? some of these attributes are an "id" such as a Type id, do the name lookup instead?
    end
    print_status("Showing #{show_type}, id #{show_obj.id} :")
    puts "\n" + tbl.to_s
    
    #
    # Table addendum for certain types
    #
    case show_type
    when 'section'        # Show Section Descriptors
       display_flag = 0
       tbl_more = Rex::Ui::Text::Table.new('Indent' => 4,
                                           'Columns' => ['section descriptors',
                                                         'values'   ])
       descriptors = SectionDescriptor.list(show_obj.id)
       descriptors.each {|descriptor|
         tbl_more << [decriptor.field_name, descriptor.value]
         display_flag = 1 
       }
       if (display_flag == 1)
         puts "\n" + tbl_more.to_s
       end
    when 'link'   # Show link fields
      display_flag = 0
      tbl_more = Rex::Ui::Text::Table.new('Indent' => 4,
                                           'Columns' => ['link fields',
                                                         'values'   ])
      link_fields = LinkField.list(show_obj.id)
      link_fields.each {|link_field|
         tbl_more << [link_field.name, link_field.value]
         display_flag = 1 
      }
      if (display_flag == 1)
        puts "\n" + tbl_more.to_s
      end
    when 'entity'  # Show entity fields
      display_flag = 0
      tbl_more = Rex::Ui::Text::Table.new('Indent' => 4,
                                           'Columns' => ['entity fields',
                                                         'values'   ])
      entity_fields = EntityField.list(show_obj.id)
      entity_fields.each {|entity_field|
         tbl_more << [entity_field.name, entity_field.value]
         display_flag = 1 
      }
      if (display_flag == 1)
        puts "\n" + tbl_more.to_s
      end
      
      # Display Links From
      ## TODO
      
      # Display Links To
      ## TODO
      
    end
    
    puts "\n"
    
  end
  
  #
  # "Show" command help
  #
  def cmd_show_help(*args)
    print_status("Command    : show")
    print_status("Description: displays the values of a selected thing.")
    print_status("Usage      : 'show [type [name]]'")
    print_status("Details    :")
    print_status("Where type and name are optional. Vaid types: project, section, transform, entity, link, entity_type, link_type.")
    print_status("By default the type and name are the current selection unless specified.")
  end
  
  
  #
  # "List" command logic
  #
  #  list [type]   (type is optional)    
  #
  def cmd_list(*args)
    # Default list type is the current default command type
    list_type = driver.interface.working_values["Default Command Type"]
    if (args.length == 1)
      list_type = args[0]
    elsif (args.length > 1)
      print_error("Ambiguous arguments.  Use -h if you need help.")
    end
    
    # Populate object names array with the contents to list
    list_objs = nil
    case list_type
    when '-h', '-?'       # List Help
        cmd_list_help
    when 'project', 'projects'        # List Project
      list_objs = Project.list()  
    when 'section', 'sections'        # List Section
      list_objs = Section.list(driver.interface.working_values["Current Project"].id)
    when 'transform', 'transforms'    # List Transform
      list_objs = Transform.list()
    when 'entity', 'entities'          # List Entity
      list_objs =  Entity.list(driver.interface.working_values["Current Project"].id, 
                               driver.interface.working_values["Current Section"].id)
    when 'link', 'links'              # List Links
      list_objs =  Link.list(driver.interface.working_values["Current Project"].id, 
                             driver.interface.working_values["Current Section"].id)
      # TODO: add list display if done while current object is an entity
    when 'entity_type', 'entity_types'  # List Entity Types
      list_objs = EntityType.list()
    when 'link_type', 'link_types'  # List Link Types
      list_objs = LinkType.list()
    else
      print_error("Invalid type argument passed to list command.")
      return                 
    end
    
    # Build table of listing with 4 columns 
    tbl = Rex::Ui::Text::Table.new('Indent' => 4,
                                   'Columns' => ['','','',''])
    col_num = 0
    row_array = Array.new()
      
    list_objs.each do |list_obj|
      if (col_num > 3)
        tbl << row_array
        row_array = Array.new()
        col_num = 0
      end
      row_array << list_obj.title
      col_num = col_num + 1  
    end  # End of table loop
      
    if (col_num > 0)
      while (col_num <= 3)
        row_array << ''
        col_num = col_num + 1
      end
      tbl << row_array
    end  # End of table completion
    
    print_status("Listing #{list_type}(s) :")  
    puts tbl.to_s + "\n"  
  end
  
  #
  # "List" command help
  #
  def cmd_list_help(*args)
    print_status("Command    : list")
    print_status("Description: displays list of things of a certain type.")
    print_status("Usage      : 'list [type]'")
    print_status("Details    :")
    print_status("Where type is optional. Vaid types: project(s), section(s), transform(s), entity(s), link(s), entity_type(s), link_type(s).")
    print_status("By default the type is the current default type.")
  end
  
  #
  # "Select" command logic
  #  select [type] <name>
  #
  def cmd_select(*args)
 
    type = ''
    name = '' 
    obj  = nil 
     
    if (args.length == 1)
      type = driver.interface.working_values["Default Command Type"]
      name = args[0]
    elsif (args.length == 2)
      type = args[0]
      name = args[1]
    else    
      print_error("Invalid number of arguments passed to select command.")
      cmd_select_help
      return
    end
  
    case type
    when '-h', '-?' 
      cmd_select_help
      return
    when 'project'
      obj = Project.select(name)
      driver.interface.working_values["Current Project"] = obj
      driver.interface.working_values["Current Object"] = driver.interface.working_values["Current Project"]
      driver.enstack_dispatcher(ProjectDispatcher)
    when 'section'
      obj = Section.select(driver.interface.working_values["Current Project"].id, name)
      driver.interface.working_values["Current Section"] = obj
      driver.interface.working_values["Current Object"] = driver.interface.working_values["Current Section"]
      driver.enstack_dispatcher(SectionDispatcher)
    when 'transform'
      obj = Transform.select(name)
      driver.interface.working_values["Current Transform"] = obj
      driver.interface.working_values["Current Object"] = driver.interface.working_values["Current Transform"]
      driver.enstack_dispatcher(TransformDispatcher)
    when 'entity'
      obj = Entity.select(driver.interface.working_values["Current Project"].id, 
                          driver.interface.working_values["Current Section"].id, 
                          name)
      driver.interface.working_values["Current Entity"] = obj
      driver.interface.working_values["Current Object"] = driver.interface.working_values["Current Entity"]
      driver.enstack_dispatcher(EntityDispatcher)
    when 'link'
      obj = Link.select_by_name(driver.interface.working_values["Current Project"].id, 
                                driver.interface.working_values["Current Section"].id, 
                                name)
      driver.interface.working_values["Current Link"] = obj
      driver.interface.working_values["Current Object"] = driver.interface.working_values["Current Link"]
      driver.enstack_dispatcher(LinkDispatcher)
    when 'entity_type'
      obj = EntityType.select(name)
      driver.interface.working_values["Current EntityType"] = obj
      driver.interface.working_values["Current Object"] = driver.interface.working_values["Current EntityType"]
      driver.enstack_dispatcher(EntityTypeDispatcher)
    when 'link_type'
      obj = LinkType.select(name)
      driver.interface.working_values["Current LinkType"] = obj
      driver.interface.working_values["Current Object"] = driver.interface.working_values["Current LinkType"]
      driver.enstack_dispatcher(LinkTypeDispatcher)  
    else
      print_error("Invalid type: #{type}")
      return
    end
    
    #if (id < 1)
    if (obj.nil?)
      print_error("Invalid #{type} name, use list for list of valid #{type}s.")
      return   
    else
      driver.interface.working_values["Current Selection Type"] = type
      driver.interface.update_default_type()
      print_status("Selected #{type}, id #{obj.id}")
      self.set_prompt()
    end
    
  end
  
  #
  # "Select" command help
  #
  def cmd_select_help(*args)
    print_status("Command    : select")
    print_status("Description: select a thing for manipulation.")
    print_status("Usage      : 'select [type] <name>'")
    print_status("Details    :")
    print_status("Where type is optional and name is required. Vaid types: project, section, transform, entity, link, entity_type, link_type.")
    print_status("The default type is the currently default type.")
  end
  
  #
  # "Create" command logic
  #  create [type] <name>
  #
  def cmd_create(*args)
 
    type = ''
    name = '' 
    obj  = nil
     
    if (args.length == 1)
      if ((args[0] == '-h') || (args[0] == '-?'))
        cmd_create_help
        return
      end
      type = driver.interface.working_values["Default Command Type"]
      name = args[0]
    elsif (args.length == 2)
      type = args[0]
      name = args[1]
    else    
      print_error("Invalid number of arguments passed to create command.")
      cmd_create_help
      return
    end
  
    case type
    when '-h', '-?' 
      cmd_create_help
      return
    when 'project'
      obj = Project.select_or_insert(name)
      driver.interface.working_values["Current Project"] = obj
      driver.interface.working_values["Current Object"] = driver.interface.working_values["Current Project"]
      driver.enstack_dispatcher(ProjectDispatcher)
    when 'section'
      obj = Section.select_or_insert(driver.interface.working_values["Current Project"].id, name)
      driver.interface.working_values["Current Section"] = obj
      driver.interface.working_values["Current Object"] = driver.interface.working_values["Current Section"]
      driver.enstack_dispatcher(SectionDispatcher)
    when 'transform'
      obj = Transform.select_or_insert(name)
      driver.interface.working_values["Current Transform"] = obj
      driver.interface.working_values["Current Object"] = driver.interface.working_values["Current Transform"]
      driver.enstack_dispatcher(TransformDispatcher)
    when 'entity'
      obj = Entity.select_or_insert(driver.interface.working_values["Current Project"].id, 
                                    driver.interface.working_values["Current Section"].id, 
                                    name)
      driver.interface.working_values["Current Entity"] = obj
      driver.interface.working_values["Current Object"] = driver.interface.working_values["Current Entity"]
      driver.enstack_dispatcher(EntityDispatcher)
    when 'link'
      obj = Link.select_or_insert(driver.interface.working_values["Current Project"].id, 
                                  driver.interface.working_values["Current Section"].id, 
                                  name)
      driver.interface.working_values["Current Link"] = obj
      driver.interface.working_values["Current Object"] = driver.interface.working_values["Current Link"]
      driver.enstack_dispatcher(LinkDispatcher)
    when 'entity_type'
      obj = EntityType.select_or_insert(name)
      driver.interface.working_values["Current EntityType"] = obj
      driver.interface.working_values["Current Object"] = driver.interface.working_values["Current EntityType"]
      driver.enstack_dispatcher(EntityTypeDispatcher)
    when 'link_type'
      obj = LinkType.select_or_insert(name)
      driver.interface.working_values["Current LinkType"] = obj
      driver.interface.working_values["Current Object"] = driver.interface.working_values["Current LinkType"]
      driver.enstack_dispatcher(LinkTypeDispatcher)  
    else
      print_error("Invalid type: #{type}")
      return
    end
    
    if (obj.nil?)
      print_error("Invalid #{type} name, use list for list of valid #{type}s.")
      return   
    else
      driver.interface.working_values["Current Selection Type"] = type
      driver.interface.update_default_type()
      print_status("Created #{type}, id #{obj.id}")
      self.set_prompt()
    end
    
  end
  
  #
  # "Create" command help
  #
  def cmd_create_help(*args)
    print_status("Command    : create")
    print_status("Description: create a thing for manipulation.")
    print_status("Usage      : 'create [type] <name>'")
    print_status("Details    :")
    print_status("Where type is optional and name is required. Vaid types: project, section, transform, entity, link, entity_type, link_type.")
    print_status("The default type is the current default type.")
  end
  
  #
  # "Set" command logic
  # set <field> <value>
  #
  def cmd_set(*args)

    type   = driver.interface.working_values["Current Selection Type"]
    object = driver.interface.working_values["Current Object"]
    
    if (args.length != 2)
      print_error("Set command takes a field/value parameter.")
      cmd_set_help()
      return
    end
    
    field = args[0]
    value = args[1]
     
    # TODO: error check to ensure that the field exists and the value is valid
    object.update_attributes(field => value)
    object.save 
    print_status("Updated #{field} to #{value}")
    self.set_prompt
  end
  
  #
  # "Set" command help
  #
  def cmd_set_help(*args)
    print_status("Command    : set")
    print_status("Description: set a field/value pair for a selected thing.")
    print_status("Usage      : 'set <field> <value>'")
  end
  
  #
  # "Delete" command logic
  #  delete [type] <name>
  #
  def cmd_delete(*args)
    
    type = ''
    name = '' 
    obj  = nil
     
    if (args.length == 1)
      type = driver.interface.working_values["Default Command Type"]
      name = args[0]
      if ((name == '-?') || (name == '-h'))
        cmd_delete_help
        return
      end
    elsif (args.length == 2)
      type = args[0]
      name = args[1]
    else    
      print_error("Invalid number of arguments passed to delete command.")
      cmd_delete_help
      return
    end  
    
    case type
    when '-h', '-?' 
      cmd_delete_help
      return
    when 'project'
      obj = Project.delete_from_name(name) 
    when 'section'
      obj = Section.delete_from_name(driver.interface.working_values["Current Project"].id, name)
    when 'transform'
      obj = Transform.delete_from_name(name)
    when 'entity'
      obj = Entity.delete_from_name(driver.interface.working_values["Current Project"].id, 
                                    driver.interface.working_values["Current Section"].id, 
                                    name)
    when 'link'
      obj = Link.delete_from_name(driver.interface.working_values["Current Project"].id, 
                                  driver.interface.working_values["Current Section"].id, 
                                  name)
    when 'descriptor'
      obj = Link.delete_from_name(driver.interface.working_values["Current Section"].id, 
                                  name)
    else
      print_error("Invalid type")
      return
    end
    
    if (obj.nil?)
      print_error("Invalid #{type} name, use list for list of valid #{type}s.")
    else
      print_status("Deleted #{type}, id #{obj.id}")
    end 
    
    ## TODO prevent from happening or update prompt if current thing is deleted
    
  end
  
  #
  # "Delete" command help
  #
  def cmd_delete_help(*args)
    print_status("Command    : delete")
    print_status("Description: delete a thing.")
    print_status("Usage      : 'delete [type] <name>'")
    print_status("Details    :")
    print_status("Where type is optional and name is required. Vaid types: project, section, descriptor, transform, entity, link, entity_type, link_type.")
    print_status("The default type is the current default command type.")
  end
  
  #
  # Export command logic
  #
  def cmd_export(*args)
    if (args.length < 1)
      cmd_export_help
      return
    end
    
    format_type = args[0]
    case format_type
    when "-h", "-?"
      cmd_export_help
      return
    when "graphviz"
      gv_generator = GraphvizGenerator.new(driver.interface.working_values)
      gv_generator.export()
    else
      print_error("Invalid export format.")
      return
    end
    
    
  end
  
  #
  # Export command help
  #
  def cmd_export_help(*args)
    print_status("Export things at and below current selection into a format.")
    print_status("Command    : export")
    print_status("Description: export things that are at and below the current selection into another format.")
    print_status("Usage      : 'export <format>'")
  end
  
  #
  # "Exit" command logic
  #
  def cmd_exit(* args)
    driver.stop
  end
  
  #
  # "Quit" command alias
  #
  alias cmd_quit cmd_exit
  
end  # Class end

end end end  # Module ends
