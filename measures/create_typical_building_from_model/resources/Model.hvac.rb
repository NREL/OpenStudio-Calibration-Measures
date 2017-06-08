class OpenStudio::Model::Model

  # Adds the HVAC system as derived from the combinations of
  # CBECS 2012 MAINHT and MAINCL fields.
  # Mapping between combinations and HVAC systems per
  # http://www.nrel.gov/docs/fy08osti/41956.pdf
  # Table C-31
  def add_cbecs_hvac_system(template, system_type, zones)

    case system_type
    when 'PTAC w/ hot water heat'
      add_hvac_system(template, 'PTAC', ht='NaturalGas', znht=nil, cl='Electricity', zones)

    when 'PTAC w/ gas coil heat'
      add_hvac_system(template, 'PTAC', ht=nil, znht='NaturalGas', cl='Electricity', zones)

    when 'PTAC w/ electric baseboard heat'
      add_hvac_system(template, 'PTAC', ht=nil, znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Baseboards', ht='Electricity', znht=nil, cl=nil, zones)

    when 'PTAC w/ no heat'
      add_hvac_system(template, 'PTAC', ht=nil, znht=nil, cl='Electricity', zones)

    when 'PTAC w/ district hot water heat'
      add_hvac_system(template, 'PTAC', ht='DistrictHeating', znht=nil, cl='Electricity', zones)

    when 'PTHP'
      add_hvac_system(template, 'PTHP', ht='Electricity', znht=nil, cl='Electricity', zones)

    when 'PSZ-AC w/ gas coil heat'
      add_hvac_system(template, 'PSZ-AC', ht='NaturalGas', znht=nil, cl='Electricity', zones)

    when 'PSZ-AC w/ electric baseboard heat'
      add_hvac_system(template, 'PSZ-AC', ht=nil, znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Baseboards', ht='Electricity', znht=nil, cl=nil, zones)

    when 'PSZ-AC w/ no heat'
      add_hvac_system(template, 'PSZ-AC', ht=nil, znht=nil, cl='Electricity', zones)

    when 'PSZ-AC w/district hot water heat'
      add_hvac_system(template, 'PSZ-AC', ht='DistrictHeating', znht=nil, cl='Electricity', zones)

    when 'PSZ-HP'
      add_hvac_system(template, 'PSZ-HP', ht='Electricity', znht=nil, cl='Electricity', zones)

    when 'Fan coil district chilled water w/ no heat'
      add_hvac_system(template, 'Fan Coil', ht=nil, znht=nil, cl='DistrictCooling', zones)

    when 'Fan coil district chilled water and boiler'
      add_hvac_system(template, 'Fan Coil', ht='NaturalGas', znht=nil, cl='DistrictCooling', zones)

    when 'Fan coil district chilled water unit heaters'
      add_hvac_system(template, 'Fan Coil', ht=nil, znht=nil, cl='DistrictCooling', zones)
      add_hvac_system(template, 'Unit Heaters', ht='NaturalGas', znht=nil, cl=nil, zones)

    when 'Fan coil district chilled water electric baseboard heat'
      add_hvac_system(template, 'Fan Coil', ht=nil, znht=nil, cl='DistrictCooling', zones)
      add_hvac_system(template, 'Baseboards', ht='Electricity', znht=nil, cl=nil, zones)

    when 'Fan coil district hot and cold water'
      add_hvac_system(template, 'Fan Coil', ht='DistrictHeating', znht=nil, cl='DistrictCooling', zones)

    when 'Fan coil district hot water and chiller'
      add_hvac_system(template, 'Fan Coil', ht='DistrictHeating', znht=nil, cl='Electricity', zones)

    when 'Fan coil chiller w/ no heat'
      add_hvac_system(template, 'Fan Coil', ht=nil, znht=nil, cl='Electricity', zones)

    when 'Baseboard district hot water heat'
      add_hvac_system(template, 'Baseboards', ht='DistrictHeating', znht=nil, cl=nil, zones)

    when 'Baseboard district hot water heat w/ direct evap coolers'
      add_hvac_system(template, 'Baseboards', ht='DistrictHeating', znht=nil, cl=nil, zones)
      add_hvac_system(template, 'Evaporative Cooler', ht=nil, znht=nil, cl='Electricity', zones)

    when 'Baseboard electric heat'
      add_hvac_system(template, 'Baseboards', ht='Electricity', znht=nil, cl=nil, zones)

    when 'Baseboard electric heat w/ direct evap coolers'
      add_hvac_system(template, 'Baseboards', ht='Electricity', znht=nil, cl=nil, zones)
      add_hvac_system(template, 'Evaporative Cooler', ht=nil, znht=nil, cl='Electricity', zones)

    when 'Baseboard hot water heat'
      add_hvac_system(template, 'Baseboards', ht='NaturalGas', znht=nil, cl=nil, zones)

    when 'Baseboard hot water heat w/ direct evap coolers'
      add_hvac_system(template, 'Baseboards', ht='NaturalGas', znht=nil, cl=nil, zones)
      add_hvac_system(template, 'Evaporative Cooler', ht=nil, znht=nil, cl='Electricity', zones)

    when 'Window AC w/ no heat'
      add_hvac_system(template, 'Window AC', ht=nil, znht=nil, cl='Electricity', zones)

    when 'Window AC w/ forced air furnace'
      add_hvac_system(template, 'Window AC', ht=nil, znht=nil, cl='Electricity', zones)
      # TODO Forced air furnace

    when 'Window AC w/ district hot water baseboard heat'
      add_hvac_system(template, 'Window AC', ht=nil, znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Baseboards', ht='DistrictHeating', znht=nil, cl=nil, zones)

    when 'Window AC w/ hot water baseboard heat'
      add_hvac_system(template, 'Window AC', ht=nil, znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Baseboards', ht='NaturalGas', znht=nil, cl=nil, zones)

    when 'Window AC w/ electric baseboard heat'
      add_hvac_system(template, 'Window AC', ht=nil, znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Baseboards', ht='Electricity', znht=nil, cl=nil, zones)

    when 'Window AC w/ unit heaters'
      add_hvac_system(template, 'Window AC', ht=nil, znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Unit Heaters', ht='NaturalGas', znht=nil, cl=nil, zones)

    when 'Direct evap coolers'
      add_hvac_system(template, 'Evaporative Cooler', ht=nil, znht=nil, cl='Electricity', zones)

    when 'Direct evap coolers w/ unit heaters'
      add_hvac_system(template, 'Evaporative Cooler', ht=nil, znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Unit Heaters', ht='NaturalGas', znht=nil, cl=nil, zones)

    when 'Unit heaters'
      add_hvac_system(template, 'Unit Heaters', ht='NaturalGas', znht=nil, cl=nil, zones)
  
    when 'Heat pump heating w/ no cooling'
      # TODO heat-only heat pump
    
    when 'Heat pump heating w/ direct evap cooler'
      # TODO heat-only heat pump
      add_hvac_system(template, 'Evaporative Cooler', ht=nil, znht=nil, cl='Electricity', zones)

    when 'VAV w/ reheat'
      add_hvac_system(template, 'VAV Reheat', ht='NaturalGas', znht='NaturalGas', cl='Electricity', zones)

    when 'PVAV w/ reheat', 'Packaged VAV Air Loop with Boiler' # second enumeration for backwards compatibility with Tenant Star project
      add_hvac_system(template, 'PVAV Reheat', ht='NaturalGas', znht='NaturalGas', cl='Electricity', zones)

    when 'PVAV w/ PFP boxes'
      add_hvac_system(template, 'PVAV PFP Boxes', ht='Electricity', znht='Electricity', cl='Electricity', zones)

    when 'Residential forced air'
      add_hvac_system(template, 'Unit Heaters', ht='NaturalGas', znht=nil, cl=nil, zones)

    end

  end

end
