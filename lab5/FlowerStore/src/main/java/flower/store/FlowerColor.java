package flower.store;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
public enum FlowerColor {
    RED("#FF0000"),
    BLUE("#0000FF"),
    YELLOW("#FFFF00");

    private final String colorCode;
    FlowerColor(String colorCode){
        this.colorCode = colorCode;
    }
}
