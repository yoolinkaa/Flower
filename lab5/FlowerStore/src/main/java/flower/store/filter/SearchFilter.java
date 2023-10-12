package flower.store.filter;

import flower.store.Item;

public interface SearchFilter {
    public boolean match(Item item);
}
