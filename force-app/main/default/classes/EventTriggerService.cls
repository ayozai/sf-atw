public with sharing class EventTriggerService {

    private static final String ERROR_MESSAGE =
        'You are not authorized to delete Events. / ' +
        'Vous n\'êtes pas autorisé à supprimer des Événements.';

    public static void blockDelete(List<Event> events) {
        if (FeatureManagement.checkPermission('Bypass_Event_Delete')) {
            return;
        }
        for (Event e : events) {
            e.addError(ERROR_MESSAGE);
        }
    }
}