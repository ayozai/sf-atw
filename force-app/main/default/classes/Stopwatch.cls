public class Stopwatch {
    private DateTime start;
    private DateTime stop;

    public Stopwatch(){ }

    public void start(){
        this.start = DateTime.now();
    }

    public void reset(){
        this.start = DateTime.now();
    }

    public void stop(){
        this.stop = DateTime.now();
    }

    public Decimal Elapsed{
        get{
            if(this.start == null || this.stop == null || (this.stop <= this.start))
                return 0.0;
            
            Decimal elapsed = (this.stop.getTime() - this.start.getTime()) / 1000.0;

            return elapsed.setScale(4, RoundingMode.HALF_UP);
        }
    }
}