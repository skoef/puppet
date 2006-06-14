# The standard init-based service type.  Many other service types are
# customizations of this module.
Puppet.type(:service).newsvctype(:init) do
    def self.defpath
        case Facter["operatingsystem"].value
        when "FreeBSD":
            "/etc/rc.d"
        else
            "/etc/init.d"
        end
    end

    Puppet.type(:service).newpath(:init, defpath())

    # Set the default init directory.
    Puppet.type(:service).attrclass(:path).defaultto defpath()

    # List all services of this type.  This has to be an instance method
    # so that it's inherited by submodules.
    def list(name)
        # We need to find all paths specified for our type or any parent types
        paths = Puppet.type(:service).paths(name)

        # Now see if there are any included modules
        included_modules.each do |mod|
            next unless mod.respond_to? :name

            mname = mod.name

            if mpaths = Puppet.type(:service).paths(mname) and ! mpaths.empty?
                 paths += mpaths
            end
        end

        paths.each do |path|
            unless FileTest.directory?(path)
                Puppet.notice "Service path %s does not exist" % path
                next
            end

            check = [:ensure]

            if public_method_defined? :enabled?
                check << :enable
            end

            Dir.entries(path).reject { |e|
                fullpath = File.join(path, e)
                e =~ /^\./ or ! FileTest.executable?(fullpath)
            }.each do |name|
                if obj = Puppet::Type.type(:service)[name]
                    obj[:check] = check
                else
                    Puppet::Type.type(:service).create(
                        :name => name, :check => check, :path => path
                    )
                end
            end
        end
    end

    # Mark that our init script supports 'status' commands.
    def hasstatus=(value)
        case value
        when true, "true": @parameters[:hasstatus] = true
        when false, "false": @parameters[:hasstatus] = false
        else
            raise Puppet::Error, "Invalid 'hasstatus' value %s" %
                value.inspect
        end
    end

    # it'd be nice if i didn't throw the output away...
    # this command returns true if the exit code is 0, and returns
    # false otherwise
    def initcmd(cmd)
        script = self.initscript

        self.debug "Executing '%s %s' as initcmd for '%s'" %
            [script,cmd,self]

        rvalue = Kernel.system("%s %s" %
                [script,cmd])

        self.debug "'%s' ran with exit status '%s'" %
            [cmd,rvalue]


        rvalue
    end

    # Where is our init script?
    def initscript
        if defined? @initscript
            return @initscript
        else
            @initscript = self.search(self[:name])
        end
    end

    def search(name)
        self[:path].each { |path|
            fqname = File.join(path,name)
            begin
                stat = File.stat(fqname)
            rescue
                # should probably rescue specific errors...
                self.debug("Could not find %s in %s" % [name,path])
                next
            end

            # if we've gotten this far, we found a valid script
            return fqname
        }
        raise Puppet::Error, "Could not find init script for '%s'" % name
    end

    # The start command is just the init scriptwith 'start'.
    def startcmd
        self.initscript + " start"
    end

    # If it was specified that the init script has a 'status' command, then
    # we just return that; otherwise, we return false, which causes it to
    # fallback to other mechanisms.
    def statuscmd
        if self[:hasstatus]
            return self.initscript + " status"
        else
            return false
        end
    end

    # The stop command is just the init script with 'stop'.
    def stopcmd
        self.initscript + " stop"
    end
end

# $Id$
