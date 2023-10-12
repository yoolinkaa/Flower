package flower.store;

import java.util.concurrent.Flow;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import lombok.ToString;

@AllArgsConstructor
@NoArgsConstructor
@ToString
@Getter
@Setter
public class Flower {
    private double sepalLength;
    private FlowerColor color;
    private int price;
    private FlowerType flowerType;

    public Flower(Flower flower) {
        this.color = color;
        this.price = price;
        this.sepalLength = sepalLength;
        this.flowerType = flowerType;
    }

    public void setPrice(int pr) {
        this.price = pr;
    }

    // public void setColor(FlowerColor col) {
    //     this.color = col;
    // }

    public String getColor(){
        return color.getColorCode();
    }
}
