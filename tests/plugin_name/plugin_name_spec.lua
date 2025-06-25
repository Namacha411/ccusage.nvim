local plugin = require("ccusage")

describe("setup", function()
  it("works with default config", function()
    plugin.setup()
    assert(plugin.config.update_interval == 30, "default update_interval should be 30")
    assert(plugin.config.display_format == "cost", "default display_format should be 'cost'")
    assert(plugin.config.decimal_places == 4, "default decimal_places should be 4")
    assert(plugin.config.show_active_indicator == true, "default show_active_indicator should be true")
  end)

  it("works with custom config", function()
    plugin.setup({
      update_interval = 60,
      display_format = "tokens",
      decimal_places = 2,
      show_active_indicator = false
    })
    assert(plugin.config.update_interval == 60, "custom update_interval should be 60")
    assert(plugin.config.display_format == "tokens", "custom display_format should be 'tokens'")
    assert(plugin.config.decimal_places == 2, "custom decimal_places should be 2")
    assert(plugin.config.show_active_indicator == false, "custom show_active_indicator should be false")
  end)

  it("has required functions", function()
    assert(type(plugin.setup) == "function", "should have setup function")
    assert(type(plugin.get_status) == "function", "should have get_status function")
    assert(type(plugin.refresh) == "function", "should have refresh function")
    assert(type(plugin.get_lualine_component) == "function", "should have get_lualine_component function")
  end)

  it("get_lualine_component returns valid component", function()
    local component = plugin.get_lualine_component()
    assert(type(component) == "table", "should return a table")
    assert(type(component[1]) == "function", "should have a function in first position")
    assert(type(component.cond) == "function", "should have a cond function")
  end)
end)

