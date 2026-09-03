public with sharing class EventTriggerHandler {
    public static void handle(TriggerOperation op, List<Event> oldList) {
        switch on op {
            when BEFORE_DELETE {
                EventTriggerService.blockDelete(oldList);
            }
        }
    }
}