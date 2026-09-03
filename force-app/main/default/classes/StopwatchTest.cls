@IsTest
public class StopwatchTest {

    @isTest
    public static void test_stopwatch_Success(){
        Stopwatch watch = new Stopwatch();
        watch.start();
        sleep(2000);
        watch.stop();

        System.assert(watch.Elapsed >= 2.0);
    }

    @isTest
    public static void test_stopwatch_InvalidStop(){
        Stopwatch watch = new Stopwatch();
        watch.stop();
        watch.reset();
        
        System.assert(watch.Elapsed == 0.0);
    }

    private static void sleep(Long milliSeconds)
    {
        Long timeDiff = 0;
        DateTime firstTime = System.now();
        do
        {
            timeDiff = System.now().getTime() - firstTime.getTime();
        }
        while(timeDiff <= milliSeconds);
    }
}