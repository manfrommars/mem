#include <stdlib.h>

struct node {
    int i;
    struct node* next;
};

void append_new_node_to_list(struct node** list) {
    struct node* l = *list;
    struct node* n = calloc(1, sizeof(struct node));
    if (l) {
        while (l->next) {
            l = l->next;
        }
        l->next = n;
    } else {
        *list = n;
    }
}

void destroy_linked_list(struct node* list) {
    while (list) {
        struct node* temp = list;
        list = list->next;
        free(temp);
    }
}

int main() {
    struct node* list = NULL;
    append_new_node_to_list(&list);
    append_new_node_to_list(&list);

    destroy_linked_list(list);
    return 0;
}