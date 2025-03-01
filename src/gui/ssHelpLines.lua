---------------------------------------------------------------------------------------------------------
-- HELP LINES FOR HELP IN INGAMEMENU
---------------------------------------------------------------------------------------------------------
-- Authors:  Rahkiin
--

ssHelpLines = {}
g_seasons.help = ssHelpLines

function ssHelpLines:loadMap()
    self:loadFromXML(g_seasons.modDir .. "resources/gui/helpLine.xml")
end

function ssHelpLines:loadFromXML(path)
    local xmlFile = loadXMLFile("helpLine", path)


    local categoryIndex = 0
    while true do
        local categoryKey = string.format("helpLines.helpLineCategory(%d)", categoryIndex)
        if not hasXMLProperty(xmlFile, categoryKey) then break end

        local category = {}

        category.title = getXMLString(xmlFile, categoryKey .. "#title")
        category.helpLines = {}

        g_inGameMenu.helpLineCategorySelectorElement:addText(ssLang.getText(category.title))

        local lineIndex = 0
        while true do
            local lineKey = string.format("%s.helpLine(%d)", categoryKey, lineIndex)
            if not hasXMLProperty(xmlFile, lineKey) then break end

            local helpLine = {}
            helpLine.title = getXMLString(xmlFile, lineKey .. "#title")
            helpLine.items = {}

            local itemIndex = 0
            while true do
                local itemKey = string.format("%s.item(%d)", lineKey, itemIndex)
                if not hasXMLProperty(xmlFile, itemKey) then break end

                local type = getXMLString(xmlFile, itemKey .. "#type")
                local value = getXMLString(xmlFile, itemKey .. "#value")

                if value ~= nil and (value == "text" or type == "image") then
                    local item = {
                        type = type,
                        value = value,
                        heightScale = Utils.getNoNil(getXMLFloat(xmlFile, itemKey .. "#heightScale"), 1)
                    }

                    table.insert(helpLine.items, item)
                end

                itemIndex = itemIndex + 1
            end

            table.insert(category.helpLines, helpLine)
            lineIndex = lineIndex + 1
        end

        table.insert(g_inGameMenu.helpLineCategories, category)
        categoryIndex = categoryIndex + 1
    end

    delete(xmlFile)
end
