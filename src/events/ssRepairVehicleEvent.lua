---------------------------------------------------------------------------------------------------
-- REPAIR VEHICLE EVENT
---------------------------------------------------------------------------------------------------
-- Purpose:  Event sent when a vehicle is repaired
-- Authors:  Rahkiin
---------------------------------------------------------------------------------------------------

ssRepairVehicleEvent = {}
ssRepairVehicleEvent_mt = Class(ssRepairVehicleEvent, Event)
InitEventClass(ssRepairVehicleEvent, "ssRepairVehicleEvent")

-- client -> server: hey! I repaired X
--> server -> everyone: hey! X got repaired!

function ssRepairVehicleEvent:emptyNew()
    local self = Event:new(ssRepairVehicleEvent_mt)
    self.className = "ssRepairVehicleEvent"
    return self
end

function ssRepairVehicleEvent:new(vehicle)
    local self = ssRepairVehicleEvent:emptyNew()

    self.vehicle = vehicle
    self.ssLastRepairDay = vehicle.ssLastRepairDay
    self.ssYesterdayOperatingTime = vehicle.ssYesterdayOperatingTime

    return self
end

function ssRepairVehicleEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.vehicle)
    streamWriteFloat32(streamId, self.ssLastRepairDay)
    streamWriteFloat32(streamId, self.ssYesterdayOperatingTime)
end

function ssRepairVehicleEvent:readStream(streamId, connection)
    self.vehicle = readNetworkNodeObject(streamId)
    self.ssLastRepairDay = streamReadFloat32(streamId)
    self.ssYesterdayOperatingTime = streamReadFloat32(streamId)

    self:run(connection)
end

function ssRepairVehicleEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.vehicle)
    end

    if self.vehicle ~= nil then
        self.vehicle.ssLastRepairDay = self.ssLastRepairDay
        self.vehicle.ssYesterdayOperatingTime = self.ssYesterdayOperatingTime
    end
end
