trigger EventTrigger on Event (before delete) {
    EventTriggerHandler.handle(Trigger.operationType, Trigger.old);
}