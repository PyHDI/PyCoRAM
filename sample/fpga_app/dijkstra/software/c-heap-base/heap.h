#include <stdio.h>
#include <stdlib.h>
#include <time.h>

//typedef unsigned int Uint;
typedef struct heapelement Heapelement;
typedef struct priority_queue PriorityQueue;

struct heapelement
{
  Uint value;
  Uint id;
};

struct priority_queue
{
  Heapelement* heap;
  Uint size;
};

void upheap(Heapelement aNode, Heapelement* heap, Uint size)
{
  Uint idx;
  Heapelement tmp;
  idx = size + 1;
  heap[idx] = aNode;
  while(idx > 1 && heap[idx].value < heap[idx/2].value){
    //printf("exchange (%d,%d)[%d]->(%d,%d)[%d]\n", heap[idx].value, heap[idx].id, idx, heap[idx/2].value, heap[idx/2].id, idx/2);
    tmp = heap[idx];
    heap[idx] = heap[idx/2];
    heap[idx/2] = tmp;
    //printf("exchanged! (%d,%d)[%d]->(%d,%d)[%d]\n", heap[idx].value, heap[idx].id, idx, heap[idx/2].value, heap[idx/2].id, idx/2);
    idx /= 2;
  }
}

void downheap(Heapelement* heap, Uint size, Uint idx)
{
  Uint cidx;        //index for child
  Heapelement tmp;
  for(;;){
    cidx = idx * 2;
    if(cidx > size){
      break;   //it has no child
    }
    if(cidx < size){
      //printf("cidx=%d size=%d\n", cidx, size);
      if(heap[cidx].value > heap[cidx+1].value){
        cidx++;
      }
    }
    //swap if necessary
    if(heap[cidx].value < heap[idx].value){
      tmp = heap[cidx];
      heap[cidx] = heap[idx];
      heap[idx] = tmp;
      idx = cidx;
    } else {
      break;
    }
  }
}

int is_empty(PriorityQueue *q)
{
  return (q->size == 0);
}

Heapelement remove_min(Heapelement* heap, Uint size)
{
  Heapelement rv = heap[1];
  heap[1] = heap[size];
  size--;
  downheap(heap, size, 1);
  return rv;
}

void enqueue(Heapelement node, PriorityQueue *q)
{
  upheap(node, q->heap, q->size);
  q->size++;
  //printf("q->size++ %d\n", q->size);
}

Heapelement dequeue(PriorityQueue *q)
{
  Heapelement rv = remove_min(q->heap, q->size);
  q->size--;
  //printf("q->size-- %d, val=%d\n", q->size, rv.value);
  return rv; 
}

void init_queue(PriorityQueue *q, Uint n)
{
  q->size = 0;
  q->heap = (Heapelement*) malloc(sizeof(Heapelement) * (n+1));
  if(q->heap == NULL){
    //printf("can allocate a memory for heap.\n");
    exit(-1);
  }
}

#ifdef AAAA
// Everything is from "http://www.roman10.net/priority-queue-and-an-implementation-using-heap-in-c/"
int main(int argc, char **argv)
{
  int n; 
  int i;
  
  PriorityQueue q;
  Heapelement hn;
  
  n = atoi(argv[1]);
  init_queue(&q, n);
  srand(time(NULL));
  
  for(i = 0; i < n; i++){
    hn.value = rand()%10000;
    printf("enqueue node with value: %d\n", hn.value);
    enqueue(hn, &q);
  }
  
  printf("\ndequeue all values:\n");
  
  for(i = 0; i < n; i++){
    hn = dequeue(&q);
    printf("dequeued node with value: %d, queue size after removal: %d\n", hn.value, q.size);
  }
  return 0;
}
#endif
